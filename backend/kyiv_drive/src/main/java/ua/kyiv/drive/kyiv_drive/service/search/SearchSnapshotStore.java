package ua.kyiv.drive.kyiv_drive.service.search;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.core.io.ClassPathResource;
import org.springframework.dao.DataAccessException;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.ObjectMapper;
import ua.kyiv.drive.kyiv_drive.config.OperationDeadline;
import ua.kyiv.drive.kyiv_drive.config.SearchCacheProperties;
import ua.kyiv.drive.kyiv_drive.exception.TripSearchException;
import ua.kyiv.drive.kyiv_drive.model.search.SearchQuery;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.TimeUnit;

@Slf4j
@Component
public class SearchSnapshotStore {
    private static final int MAX_SERIALIZED_BYTES = 8 * 1024 * 1024;
    private static final DefaultRedisScript<Long> WRITE = new DefaultRedisScript<>();
    private static final DefaultRedisScript<String> BEGIN_SEARCH = new DefaultRedisScript<>("""
            redis.call('SET', KEYS[1], ARGV[1], 'PX', ARGV[2])
            return redis.call('GET', KEYS[2]) or ''
            """, String.class);
    private static final DefaultRedisScript<String> READ_METADATA = new DefaultRedisScript<>("""
            if redis.call('GET', KEYS[1]) ~= ARGV[1] or redis.call('HEXISTS', KEYS[2], 'data') == 0 then return nil end
            local definition, state = redis.call('HGET', KEYS[2], 'meta'), redis.call('HGET', KEYS[2], 'state')
            if not definition or not state then return nil end
            return '{"definition":' .. definition .. ',"state":' .. state .. '}'
            """, String.class);
    static {
        WRITE.setLocation(new ClassPathResource("redis/trip_search_context.lua"));
        WRITE.setResultType(Long.class);
    }
    private final StringRedisTemplate redis;
    private final ObjectMapper mapper;
    private final SearchCacheProperties properties;

    public SearchSnapshotStore(@Qualifier("searchCacheRedisTemplate") StringRedisTemplate redis,
                               ObjectMapper mapper, SearchCacheProperties properties) {
        this.redis = redis;
        this.mapper = mapper;
        this.properties = properties;
    }

    private record Definition(UUID ownerId, UUID sessionId, SearchQuery query, String graphRevision,
                              String formulaVersion, BigDecimal priceMedian) { }
    private record State(List<SearchContextMetadata.Variant> variants, long sequence) { }
    private record Envelope(Definition definition, State state) { }

    public record PendingSearch(UUID contextId, UUID previousContext) { }

    public PendingSearch beginSearch(UUID owner, UUID session) {
        var deadline = OperationDeadline.current();
        long ttl = deadline == null ? properties.getSnapshotTtl().toMillis()
                : TimeUnit.NANOSECONDS.toMillis(deadline.remainingNanos());
        UUID context = UUID.randomUUID();
        try {
            String previous = redis.execute(BEGIN_SEARCH,
                    List.of(pendingKey(owner, session), activeKey(owner, session)),
                    context.toString(), Long.toString(Math.max(1, ttl)));
            if (previous == null) throw unavailable(null);
            return new PendingSearch(context, previous.isEmpty() ? null : UUID.fromString(previous));
        } catch (DataAccessException e) {
            throw unavailable(e);
        } catch (IllegalArgumentException e) {
            throw expired();
        }
    }

    public void requirePending(UUID owner, UUID session, UUID context) {
        OperationDeadline.check();
        try {
            if (!context.toString().equals(redis.opsForValue().get(pendingKey(owner, session)))) {
                throw superseded();
            }
        } catch (DataAccessException e) {
            throw unavailable(e);
        }
    }

    public UUID activeContext(UUID owner, UUID session) {
        OperationDeadline.check();
        try {
            String value = redis.opsForValue().get(activeKey(owner, session));
            return value == null ? null : UUID.fromString(value);
        } catch (DataAccessException e) {
            throw unavailable(e);
        } catch (IllegalArgumentException e) {
            throw expired();
        }
    }

    public SearchContextMetadata metadata(UUID owner, UUID session, UUID context) {
        OperationDeadline.check();
        try {
            String json = redis.execute(READ_METADATA,
                    List.of(activeKey(owner, session), contextKey(owner, session, context)), context.toString());
            if (json == null) throw expired();
            Envelope envelope = mapper.readValue(json, Envelope.class);
            Definition definition = envelope.definition();
            State state = envelope.state();
            return new SearchContextMetadata(definition.ownerId(), definition.sessionId(), definition.query(),
                    definition.graphRevision(), definition.formulaVersion(), definition.priceMedian(),
                    state.variants(), state.sequence());
        } catch (DataAccessException e) {
            throw unavailable(e);
        } catch (JacksonException e) {
            throw expired();
        }
    }

    public SearchSnapshot snapshot(UUID owner, UUID session, UUID context) {
        String json = read(owner, session, context, "data");
        if (json == null) throw expired();
        return deserialize(json, SearchSnapshot.class);
    }

    public SearchRanking ranking(UUID owner, UUID session, SearchHandle handle) {
        String json = read(owner, session, handle.contextId(), "variant:" + handle.variantId());
        return json == null ? null : deserialize(json, SearchRanking.class);
    }

    public List<Integer> order(UUID owner, UUID session, SearchHandle handle) {
        String json = read(owner, session, handle.contextId(), "order:" + handle.variantId() + ":" + handle.sort());
        return json == null ? null : Arrays.stream(deserialize(json, int[].class)).boxed().toList();
    }

    public SearchRequestIdentity identity(UUID owner, UUID session, UUID context) {
        String json = read(owner, session, context, "request");
        return json == null ? null : deserialize(json, SearchRequestIdentity.class);
    }

    public Instant publish(UUID owner, UUID session, SearchHandle handle, SearchSnapshot snapshot,
                           SearchRanking ranking, List<Integer> order, String fingerprint, UUID previous) {
        return publish(owner, session, handle, snapshot, ranking, order, fingerprint, previous, null);
    }

    public Instant publish(UUID owner, UUID session, SearchHandle handle, SearchSnapshot snapshot,
                           SearchRanking ranking, List<Integer> order, String fingerprint, UUID previous,
                           SearchRequestIdentity identity) {
        var metadata = new Definition(owner, session, snapshot.query(), snapshot.graphRevision(),
                snapshot.formulaVersion(), snapshot.priceMedian());
        var state = new State(List.of(new SearchContextMetadata.Variant(ranking.id(), fingerprint, 1)), 1);
        List<String> args = arguments("publish", handle);
        args.set(7, serialize(snapshot));
        args.set(8, serialize(metadata));
        args.set(9, serialize(ranking));
        args.set(10, serialize(order));
        args.set(11, serialize(state));
        args.set(13, previous == null ? "" : previous.toString());
        args.set(14, identity == null ? "" : serialize(identity));
        List<String> keys = new ArrayList<>(keys(owner, session, handle));
        keys.add(pendingKey(owner, session));
        if (previous != null) keys.add(contextKey(owner, session, previous));
        return execute(keys, args);
    }

    public Instant saveVariant(UUID owner, UUID session, SearchHandle handle, SearchRanking ranking,
                               List<Integer> order, String fingerprint, UUID source, boolean replace) {
        List<String> args = arguments("variant", handle);
        args.set(7, serialize(ranking));
        args.set(9, serialize(order));
        args.set(10, fingerprint);
        args.set(11, source.toString());
        args.set(12, replace ? "1" : "0");
        return execute(keys(owner, session, handle), args);
    }

    public Instant saveOrder(UUID owner, UUID session, SearchHandle handle, List<Integer> order) {
        List<String> args = arguments("order", handle);
        args.set(9, serialize(order));
        return execute(keys(owner, session, handle), args);
    }

    public Instant touch(UUID owner, UUID session, SearchHandle handle) {
        return execute(keys(owner, session, handle), arguments("touch", handle));
    }

    private List<String> arguments(String mode, SearchHandle handle) {
        if (properties.getSnapshotTtl().toMillis() <= 0) throw expired();
        List<String> args = new ArrayList<>(Collections.nCopies(15, ""));
        args.set(0, mode);
        args.set(1, handle.contextId().toString());
        args.set(2, handle.variantId().toString());
        args.set(3, handle.sort().name());
        args.set(4, Long.toString(properties.getSnapshotTtl().toMillis()));
        args.set(5, Integer.toString(properties.getMaxVariants()));
        return args;
    }

    private Instant execute(List<String> keys, List<String> args) {
        OperationDeadline.check();
        try {
            Long result = redis.execute(WRITE, keys, args.toArray());
            if (result == null) throw unavailable(null);
            if (result == -1) throw expired();
            if (result == -2) throw variantExpired();
            if (result == -3) throw new TripSearchException("trip_search_busy", HttpStatus.CONFLICT);
            if (result == -4) throw superseded();
            return Instant.ofEpochMilli(result);
        } catch (DataAccessException e) {
            throw unavailable(e);
        }
    }

    private String read(UUID owner, UUID session, UUID context, String field) {
        OperationDeadline.check();
        try {
            return (String) redis.opsForHash().get(contextKey(owner, session, context), field);
        } catch (DataAccessException e) {
            throw unavailable(e);
        }
    }

    private String serialize(Object value) {
        try {
            String json = mapper.writeValueAsString(value);
            if (json.getBytes(StandardCharsets.UTF_8).length > MAX_SERIALIZED_BYTES) {
                throw new TripSearchException("trip_search_too_broad", HttpStatus.UNPROCESSABLE_ENTITY);
            }
            return json;
        } catch (JacksonException e) {
            throw new TripSearchException("trip_search_cache_unavailable", HttpStatus.SERVICE_UNAVAILABLE, e);
        }
    }

    private <T> T deserialize(String json, Class<T> type) {
        try {
            return mapper.readValue(json, type);
        } catch (JacksonException e) {
            throw expired();
        }
    }

    private List<String> keys(UUID owner, UUID session, SearchHandle handle) {
        return List.of(activeKey(owner, session), contextKey(owner, session, handle.contextId()));
    }

    private String activeKey(UUID owner, UUID session) {
        return "trip-search:v5:active:" + owner + ":" + session;
    }

    private String pendingKey(UUID owner, UUID session) {
        return "trip-search:v5:pending:" + owner + ":" + session;
    }

    private String contextKey(UUID owner, UUID session, UUID context) {
        return "trip-search:v5:context:" + owner + ":" + session + ":" + context;
    }

    private TripSearchException unavailable(DataAccessException cause) {
        if (cause != null) log.warn("Trip search snapshot cache operation failed ({})", cause.getClass().getSimpleName());
        return new TripSearchException("trip_search_cache_unavailable", HttpStatus.SERVICE_UNAVAILABLE);
    }

    static TripSearchException superseded() {
        return new TripSearchException("trip_search_superseded", HttpStatus.CONFLICT);
    }

    public static TripSearchException expired() {
        return new TripSearchException("trip_search_expired", HttpStatus.GONE);
    }

    public static TripSearchException variantExpired() {
        return new TripSearchException("trip_search_variant_expired", HttpStatus.CONFLICT);
    }
}
