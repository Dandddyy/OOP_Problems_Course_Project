package ua.kyiv.drive.kyiv_drive.service.search.walking;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import ua.kyiv.drive.kyiv_drive.config.WalkingOsrmRequestFactory;
import ua.kyiv.drive.kyiv_drive.config.WalkingRoutingProperties;
import ua.kyiv.drive.kyiv_drive.exception.TripSearchException;
import ua.kyiv.drive.kyiv_drive.model.search.SearchCoordinate;
import ua.kyiv.drive.kyiv_drive.model.search.WalkingMetric;
import ua.kyiv.drive.kyiv_drive.validation.ServiceArea;

import java.math.BigDecimal;
import java.net.URI;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicReference;
import java.util.function.LongSupplier;
import java.util.stream.Collectors;
import java.util.stream.IntStream;

@Component
public class WalkingOsrmClient {
    private final WalkingRoutingProperties properties;
    private final ObjectMapper mapper;
    private final RestTemplate http;
    private final WalkingOsrmRequestFactory requestFactory;
    private final LongSupplier nanoTime;

    @Autowired
    public WalkingOsrmClient(WalkingRoutingProperties properties, ObjectMapper mapper,
                              @Qualifier("walkingOsrmRestTemplate") RestTemplate http,
                              WalkingOsrmRequestFactory requestFactory) {
        this(properties, mapper, http, requestFactory, System::nanoTime);
    }

    WalkingOsrmClient(WalkingRoutingProperties properties, ObjectMapper mapper, RestTemplate http,
                      WalkingOsrmRequestFactory requestFactory, LongSupplier nanoTime) {
        this.properties = properties;
        this.mapper = mapper;
        this.nanoTime = nanoTime;
        this.http = http;
        this.requestFactory = requestFactory;
    }

    private void requireTime(long deadline) {
        if (nanoTime.getAsLong() >= deadline) throw busy();
    }

    public Map<SearchCoordinate, WalkingMetric> table(SearchCoordinate anchor, List<SearchCoordinate> points,
                                                     boolean reverse, DataVersion version, long deadlineNanos) {
        if (points.isEmpty()) return Map.of();
        if (points.size() > 500) throw new IllegalArgumentException("Walking matrix batch exceeds 500 points");
        // OSRM 5.26 includes data_version in /route, but omits it from /table and /nearest.
        verifyGraphVersion(version, deadlineNanos);
        Map<SearchCoordinate, WalkingMetric> result = table(anchor, points, reverse, version,
                deadlineNanos, new AtomicReference<>());
        verifyGraphVersion(version, deadlineNanos);
        return result;
    }

    private Map<SearchCoordinate, WalkingMetric> table(SearchCoordinate anchor, List<SearchCoordinate> points,
                                                      boolean reverse, DataVersion version, long deadlineNanos,
                                                      AtomicReference<Boolean> anchorRoutable) {
        requireTime(deadlineNanos);
        List<SearchCoordinate> coordinates = new ArrayList<>();
        coordinates.add(anchor);
        coordinates.addAll(points);
        String indices = IntStream.rangeClosed(1, points.size()).mapToObj(Integer::toString)
                .collect(Collectors.joining(";"));
        String radius = number(properties.getSnapRadiusMeters());
        String radiuses = coordinates.stream().map(ignored -> radius).collect(Collectors.joining(";"));
        String path = "/table/v1/foot/" + coordinates.stream().map(WalkingOsrmClient::coordinate)
                .collect(Collectors.joining(";"));
        String options = "?annotations=distance,duration&sources=" + (reverse ? indices : "0")
                + "&destinations=" + (reverse ? "0" : indices) + "&radiuses=" + radiuses;
        JsonNode root = request(path + options, deadlineNanos);
        String code = root.path("code").asString("");
        if ("NoSegment".equals(code)) {
            version.observe(root, false);
            Boolean anchorAvailable = anchorRoutable.get();
            if (anchorAvailable == null) {
                anchorAvailable = isAnchorRoutable(anchor, version, deadlineNanos);
                anchorRoutable.set(anchorAvailable);
            }
            if (!anchorAvailable || points.size() == 1) return unreachable(points);
            int middle = points.size() / 2;
            Map<SearchCoordinate, WalkingMetric> result = new HashMap<>(table(anchor,
                    points.subList(0, middle), reverse, version, deadlineNanos, anchorRoutable));
            result.putAll(table(anchor, points.subList(middle, points.size()), reverse, version,
                    deadlineNanos, anchorRoutable));
            return result;
        }
        if ("NoTable".equals(code)) {
            version.observe(root, false);
            return unreachable(points);
        }
        if (!"Ok".equals(code)) throw unavailable(null);
        version.observe(root, false);
        JsonNode sources = root.path("sources");
        JsonNode destinations = root.path("destinations");
        JsonNode distances = root.path("distances");
        JsonNode durations = root.path("durations");
        int sourceCount = reverse ? points.size() : 1;
        int destinationCount = reverse ? 1 : points.size();
        requireArray(sources, sourceCount);
        requireArray(destinations, destinationCount);
        requireArray(distances, sourceCount);
        requireArray(durations, sourceCount);
        for (int row = 0; row < sourceCount; row++) {
            requireArray(distances.get(row), destinationCount);
            requireArray(durations.get(row), destinationCount);
        }
        Map<SearchCoordinate, WalkingMetric> result = new HashMap<>();
        double anchorOffset = snapDistance(anchor, reverse ? destinations.get(0) : sources.get(0));
        for (int i = 0; i < points.size(); i++) {
            JsonNode distance = distances.get(reverse ? i : 0).get(reverse ? 0 : i);
            JsonNode duration = durations.get(reverse ? i : 0).get(reverse ? 0 : i);
            double pointOffset = snapDistance(points.get(i), reverse ? sources.get(i) : destinations.get(i));
            if (distance.isNull() && duration.isNull()) {
                result.put(points.get(i), WalkingMetric.unreachable());
            } else {
                double meters = nonNegativeNumber(distance);
                double seconds = nonNegativeNumber(duration);
                if (anchorOffset < 0 || pointOffset < 0) {
                    result.put(points.get(i), WalkingMetric.unreachable());
                } else {
                    double connector = anchorOffset + pointOffset;
                    result.put(points.get(i), new WalkingMetric(true, meters + connector,
                            seconds + connector * properties.getConnectorSecondsPerMeter()));
                }
            }
        }
        return result;
    }

    private boolean isAnchorRoutable(SearchCoordinate anchor, DataVersion version, long deadlineNanos) {
        JsonNode root = request("/nearest/v1/foot/" + coordinate(anchor)
                + "?number=1&radiuses=" + number(properties.getSnapRadiusMeters()), deadlineNanos);
        if ("NoSegment".equals(root.path("code").asString(""))) {
            version.observe(root, false);
            return false;
        }
        if (!"Ok".equals(root.path("code").asString(""))) throw unavailable(null);
        version.observe(root, false);
        requireArray(root.path("waypoints"), 1);
        return snapDistance(anchor, root.path("waypoints").get(0)) >= 0;
    }

    private void verifyGraphVersion(DataVersion version, long deadlineNanos) {
        SearchCoordinate center = new SearchCoordinate(
                (ServiceArea.MIN_LONGITUDE + ServiceArea.MAX_LONGITUDE) / 2,
                (ServiceArea.MIN_LATITUDE + ServiceArea.MAX_LATITUDE) / 2);
        String point = coordinate(center);
        JsonNode root = request("/route/v1/foot/" + point + ";" + point
                + "?overview=false&steps=false&skip_waypoints=true", deadlineNanos);
        if (!"Ok".equals(root.path("code").asString(""))) throw unavailable(null);
        version.observe(root, true);
    }

    private JsonNode request(String path, long deadlineNanos) {
        requireTime(deadlineNanos);
        return requestFactory.withDeadline(deadlineNanos, () -> requestWithinDeadline(path, deadlineNanos));
    }

    private JsonNode requestWithinDeadline(String path, long deadlineNanos) {
        try {
            String body;
            try {
                body = http.getForObject(URI.create(properties.getUrl().replaceAll("/+$", "") + path), String.class);
            } catch (HttpClientErrorException e) {
                if (e.getStatusCode() != HttpStatus.BAD_REQUEST) throw e;
                JsonNode error = mapper.readTree(e.getResponseBodyAsString());
                requireTime(deadlineNanos);
                String code = error.path("code").asString("");
                if ("NoSegment".equals(code) || "NoTable".equals(code)) return error;
                throw e;
            }
            if (body == null) throw unavailable(null);
            JsonNode root = mapper.readTree(body);
            if (!root.isObject()) throw unavailable(null);
            requireTime(deadlineNanos);
            return root;
        } catch (RestClientException | JacksonException | IllegalArgumentException e) {
            requireTime(deadlineNanos);
            throw unavailable(e);
        }
    }

    private double snapDistance(SearchCoordinate original, JsonNode waypoint) {
        JsonNode location = waypoint.path("location");
        requireArray(location, 2);
        if (!location.get(0).isNumber() || !location.get(1).isNumber()) throw unavailable(null);
        double longitude = location.get(0).asDouble();
        double latitude = location.get(1).asDouble();
        if (!Double.isFinite(longitude) || !Double.isFinite(latitude)
                || longitude < -180 || longitude > 180 || latitude < -90 || latitude > 90) {
            throw unavailable(null);
        }
        double lat1 = Math.toRadians(original.latitude());
        double lat2 = Math.toRadians(latitude);
        double deltaLat = lat2 - lat1;
        double deltaLon = Math.toRadians(longitude - original.longitude());
        double a = Math.pow(Math.sin(deltaLat / 2), 2)
                + Math.cos(lat1) * Math.cos(lat2) * Math.pow(Math.sin(deltaLon / 2), 2);
        double distance = 6371008.8 * 2 * Math.asin(Math.sqrt(Math.min(1, a)));
        return distance <= properties.getSnapRadiusMeters() + 0.5 ? distance : -1;
    }

    private static void requireArray(JsonNode node, int size) {
        if (!node.isArray() || node.size() != size) throw unavailable(null);
    }

    private static double nonNegativeNumber(JsonNode node) {
        if (!node.isNumber()) throw unavailable(null);
        double value = node.asDouble();
        if (!Double.isFinite(value) || value < 0) throw unavailable(null);
        return value;
    }

    private static Map<SearchCoordinate, WalkingMetric> unreachable(List<SearchCoordinate> points) {
        Map<SearchCoordinate, WalkingMetric> result = new HashMap<>();
        points.forEach(point -> result.put(point, WalkingMetric.unreachable()));
        return result;
    }

    static String coordinate(SearchCoordinate point) {
        return number(point.longitude()) + "," + number(point.latitude());
    }

    private static String number(double value) {
        return BigDecimal.valueOf(value == 0 ? 0 : value).stripTrailingZeros().toPlainString();
    }

    private static TripSearchException unavailable(Throwable cause) {
        return new TripSearchException("trip_search_routing_unavailable", HttpStatus.SERVICE_UNAVAILABLE, cause);
    }

    private static TripSearchException busy() {
        return new TripSearchException("trip_search_busy", HttpStatus.SERVICE_UNAVAILABLE);
    }

    public static final class DataVersion {
        private final String expected;
        private final AtomicReference<String> observed;

        public DataVersion(String expected) {
            this(expected, new AtomicReference<>());
        }

        DataVersion(String expected, AtomicReference<String> observed) {
            this.expected = expected;
            this.observed = observed;
        }

        void observe(JsonNode root, boolean required) {
            String actual = root.path("data_version").asString("");
            if (actual.isBlank()) {
                if (required) throw unavailable(null);
                return;
            }
            if (expected != null && !expected.isBlank() && !expected.equals(actual)) throw changed();
            String first = observed.compareAndExchange(null, actual);
            if (first != null && !first.equals(actual)) throw changed();
        }

        private static TripSearchException changed() {
            return new TripSearchException("trip_search_graph_changed", HttpStatus.CONFLICT);
        }
    }
}
