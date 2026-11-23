package ua.kyiv.drive.kyiv_drive.service.search.walking;

import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Tags;
import io.micrometer.core.instrument.binder.jvm.ExecutorServiceMetrics;
import jakarta.annotation.PreDestroy;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import ua.kyiv.drive.kyiv_drive.config.WalkingRoutingProperties;
import ua.kyiv.drive.kyiv_drive.config.OperationDeadline;
import ua.kyiv.drive.kyiv_drive.exception.TripSearchException;
import ua.kyiv.drive.kyiv_drive.model.search.SearchCoordinate;
import ua.kyiv.drive.kyiv_drive.model.search.WalkingMetric;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.RejectedExecutionException;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import java.util.concurrent.atomic.AtomicReference;
import java.util.stream.Collectors;

@Service
public class WalkingRoutingService {
    private static final String POOL = "walking_routing";
    private final WalkingRoutingProperties properties;
    private final WalkingGraphRevision graph;
    private final WalkingMetricCache cache;
    private final WalkingOsrmClient client;
    private final ExecutorService executor;
    private final MeterRegistry meters;
    private final ConcurrentHashMap<String, CompletableFuture<Map<SearchCoordinate, WalkingMetric>>> pending
            = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, AtomicReference<String>> dataVersions = new ConcurrentHashMap<>();

    public WalkingRoutingService(WalkingRoutingProperties properties, WalkingGraphRevision graph,
                                 WalkingMetricCache cache, WalkingOsrmClient client, MeterRegistry meters) {
        this.properties = properties;
        this.graph = graph;
        this.cache = cache;
        this.client = client;
        this.meters = meters;
        var workers = new ThreadPoolExecutor(properties.getParallelism(), properties.getParallelism(),
                30, TimeUnit.SECONDS, new ArrayBlockingQueue<>(properties.getQueueCapacity()),
                Thread.ofPlatform().daemon().name("trip-search-walking-", 0).factory(),
                new ThreadPoolExecutor.AbortPolicy());
        this.executor = ExecutorServiceMetrics.monitor(meters, workers, POOL, Tags.empty());
    }

    public String revision() {
        return revision(graph.current());
    }

    public WalkingRoutes calculate(SearchCoordinate origin, SearchCoordinate destination,
                                   Collection<SearchCoordinate> pickups, Collection<SearchCoordinate> dropoffs) {
        OperationDeadline.check();
        var identity = graph.current();
        String revision = revision(identity);
        var requestDeadline = OperationDeadline.current();
        long walkingDeadline = System.nanoTime() + properties.getCalculationTimeout().toNanos();
        long deadline = requestDeadline == null ? walkingDeadline
                : Math.min(walkingDeadline, requestDeadline.expiresAtNanos());
        var version = new WalkingOsrmClient.DataVersion(identity.expectedDataVersion(),
                dataVersions.computeIfAbsent(revision, ignored -> new AtomicReference<>()));
        var to = direction(origin, pickups, false, revision, version, deadline);
        var from = direction(destination, dropoffs, true, revision, version, deadline);
        Map<SearchCoordinate, WalkingMetric> toPickups = await(to, deadline);
        Map<SearchCoordinate, WalkingMetric> fromDropoffs = await(from, deadline);
        if (!revision.equals(revision())) {
            throw new TripSearchException("trip_search_graph_changed", HttpStatus.CONFLICT);
        }
        return new WalkingRoutes(revision, toPickups, fromDropoffs);
    }

    private CompletableFuture<Map<SearchCoordinate, WalkingMetric>> direction(
            SearchCoordinate anchor, Collection<SearchCoordinate> requested, boolean reverse, String revision,
            WalkingOsrmClient.DataVersion version, long deadline) {
        List<SearchCoordinate> points = requested.stream().distinct()
                .sorted(Comparator.comparingDouble(SearchCoordinate::longitude)
                        .thenComparingDouble(SearchCoordinate::latitude)).toList();
        if (points.isEmpty()) return CompletableFuture.completedFuture(Map.of());
        String callKey = WalkingGraphRevision.sha256((revision + ":" + reverse + ":"
                + WalkingOsrmClient.coordinate(anchor) + ":" + points.stream()
                .map(WalkingOsrmClient::coordinate).collect(Collectors.joining(";")))
                .getBytes(StandardCharsets.UTF_8));
        var future = new CompletableFuture<Map<SearchCoordinate, WalkingMetric>>();
        var existing = pending.putIfAbsent(callKey, future);
        if (existing != null) return existing;
        try {
            executor.execute(() -> {
                try {
                    future.complete(calculateDirection(anchor, points, reverse, revision, version, deadline));
                } catch (RuntimeException e) {
                    future.completeExceptionally(e);
                } finally {
                    pending.remove(callKey, future);
                }
            });
        } catch (RejectedExecutionException e) {
            reject(executor.isShutdown() ? "shutdown" : "queue_full");
            pending.remove(callKey, future);
            future.completeExceptionally(new TripSearchException("trip_search_busy", HttpStatus.SERVICE_UNAVAILABLE, e));
        }
        return future;
    }

    private Map<SearchCoordinate, WalkingMetric> calculateDirection(
            SearchCoordinate anchor, List<SearchCoordinate> points, boolean reverse, String revision,
            WalkingOsrmClient.DataVersion version, long deadline) {
        Map<SearchCoordinate, String> keys = new LinkedHashMap<>();
        points.forEach(point -> keys.put(point, key(revision, anchor, point, reverse)));
        Map<String, WalkingMetric> cached = cache.read(keys.values());
        Map<SearchCoordinate, WalkingMetric> result = new HashMap<>();
        List<SearchCoordinate> missing = new ArrayList<>();
        for (SearchCoordinate point : points) {
            if (point.equals(anchor)) {
                result.put(point, new WalkingMetric(true, 0, 0));
            } else if (cached.containsKey(keys.get(point))) {
                result.put(point, cached.get(keys.get(point)));
            } else {
                missing.add(point);
            }
        }
        for (int offset = 0; offset < missing.size(); offset += properties.getBatchSize()) {
            if (System.nanoTime() >= deadline) {
                throw new TripSearchException("trip_search_busy", HttpStatus.SERVICE_UNAVAILABLE);
            }
            List<SearchCoordinate> batch = missing.subList(offset, Math.min(missing.size(), offset + properties.getBatchSize()));
            Map<SearchCoordinate, WalkingMetric> calculated = client.table(anchor, batch, reverse, version, deadline);
            if (!calculated.keySet().equals(new java.util.HashSet<>(batch))) {
                throw new TripSearchException("trip_search_routing_unavailable", HttpStatus.SERVICE_UNAVAILABLE);
            }
            result.putAll(calculated);
            Map<String, WalkingMetric> toCache = new HashMap<>();
            calculated.forEach((point, metric) -> toCache.put(keys.get(point), metric));
            // Do not publish results into a namespace whose active release changed mid-request.
            if (!revision.equals(revision())) {
                throw new TripSearchException("trip_search_graph_changed", HttpStatus.CONFLICT);
            }
            cache.write(toCache);
        }
        return Map.copyOf(result);
    }

    private String revision(WalkingGraphRevision.Identity identity) {
        String parameters = identity.revision() + "|" + identity.expectedDataVersion() + "|foot|connector-v1|"
                + properties.getSnapRadiusMeters() + "|" + properties.getConnectorSecondsPerMeter();
        return WalkingGraphRevision.sha256(parameters.getBytes(StandardCharsets.UTF_8));
    }

    private static String key(String revision, SearchCoordinate anchor, SearchCoordinate point, boolean reverse) {
        String from = WalkingOsrmClient.coordinate(reverse ? point : anchor);
        String to = WalkingOsrmClient.coordinate(reverse ? anchor : point);
        return "trip-search:walk:v1:" + revision + ":" + WalkingGraphRevision.sha256(
                (from + "|" + to).getBytes(StandardCharsets.UTF_8));
    }

    private Map<SearchCoordinate, WalkingMetric> await(
            CompletableFuture<Map<SearchCoordinate, WalkingMetric>> future, long deadline) {
        try {
            return future.get(Math.max(1, deadline - System.nanoTime()), TimeUnit.NANOSECONDS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            reject("interrupted");
            throw new TripSearchException("trip_search_busy", HttpStatus.SERVICE_UNAVAILABLE);
        } catch (TimeoutException e) {
            reject("calculation_timeout");
            throw new TripSearchException("trip_search_busy", HttpStatus.SERVICE_UNAVAILABLE);
        } catch (ExecutionException e) {
            if (e.getCause() instanceof TripSearchException search) {
                if ("trip_search_busy".equals(search.getCode())
                        && !(search.getCause() instanceof RejectedExecutionException) && System.nanoTime() >= deadline) {
                    reject("calculation_timeout");
                }
                throw search;
            }
            throw new TripSearchException("trip_search_routing_unavailable", HttpStatus.SERVICE_UNAVAILABLE, e.getCause());
        }
    }

    private void reject(String reason) {
        meters.counter("kyivdrive.executor.rejections", "name", POOL, "reason", reason).increment();
    }

    @PreDestroy
    public void close() {
        executor.shutdownNow();
    }
}
