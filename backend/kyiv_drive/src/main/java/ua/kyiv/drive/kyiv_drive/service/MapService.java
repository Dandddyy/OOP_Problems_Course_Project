package ua.kyiv.drive.kyiv_drive.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import org.springframework.web.client.RestTemplate;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import ua.kyiv.drive.kyiv_drive.config.OperationDeadline;
import ua.kyiv.drive.kyiv_drive.dto.map.AddressDTO;
import ua.kyiv.drive.kyiv_drive.dto.map.RouteDTO;
import ua.kyiv.drive.kyiv_drive.dto.map.RouteRequestDTO;
import ua.kyiv.drive.kyiv_drive.dto.map.RouteWithStopsDTO;
import ua.kyiv.drive.kyiv_drive.dto.map.StopOnRouteDTO;
import ua.kyiv.drive.kyiv_drive.entity.TripWaypoint;
import ua.kyiv.drive.kyiv_drive.exception.OperationTimeoutException;
import ua.kyiv.drive.kyiv_drive.repository.StopFractionProjection;
import ua.kyiv.drive.kyiv_drive.repository.StopRepository;
import ua.kyiv.drive.kyiv_drive.service.limit.RequestRateLimits;
import ua.kyiv.drive.kyiv_drive.validation.InputValidation;
import ua.kyiv.drive.kyiv_drive.validation.RoutePolicy;
import ua.kyiv.drive.kyiv_drive.validation.RoutePolicyValidator;
import ua.kyiv.drive.kyiv_drive.validation.ServiceArea;

import java.time.Duration;
import java.util.*;

@Slf4j
@Service
public class MapService {

    @Value("${geoapify.api.key}")
    private String geoapifyApiKey;

    @Value("${osrm.routing.url}")
    private String osrmUrl;

    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper;
    private final StringRedisTemplate cacheRedis;
    private final StopRepository stopRepository;
    private final RequestRateLimits rateLimits;

    public MapService(RestTemplate restTemplate, ObjectMapper objectMapper,
                      @Qualifier("searchCacheRedisTemplate") StringRedisTemplate cacheRedis,
                      StopRepository stopRepository, RequestRateLimits rateLimits) {
        this.restTemplate = restTemplate;
        this.objectMapper = objectMapper;
        this.cacheRedis = cacheRedis;
        this.stopRepository = stopRepository;
        this.rateLimits = rateLimits;
    }

    private static final Duration CACHE_DURATION = Duration.ofDays(7);

    public AddressDTO getAddressByCoordinates(double lat, double lon) {
        String currentLanguage = validateLanguage(LocaleContextHolder.getLocale().getLanguage());
        String latKey = String.format(Locale.US, "%.4f", lat);
        String lonKey = String.format(Locale.US, "%.4f", lon);
        String cacheKey = "geo:rev:v5:" + latKey + ":" + lonKey + ":" + currentLanguage;

        try {
            String cachedValue = cacheRedis.opsForValue().get(cacheKey);
            if (StringUtils.hasText(cachedValue)) {
                return objectMapper.readValue(cachedValue, AddressDTO.class);
            }
        } catch (Exception e) {
            log.error("Redis Cache Read Error (Reverse Geocoding): {}", e.getMessage(), e);
        }

        Map<String, Object> uriVariables = new HashMap<>();
        uriVariables.put("lat", lat);
        uriVariables.put("lon", lon);
        uriVariables.put("lang", currentLanguage);
        uriVariables.put("apiKey", geoapifyApiKey);

        String urlTemplate = "https://api.geoapify.com/v1/geocode/reverse?lat={lat}&lon={lon}&lang={lang}&apiKey={apiKey}";

        try {
            ResponseEntity<String> response = restTemplate.getForEntity(urlTemplate, String.class, uriVariables);
            JsonNode root = objectMapper.readTree(response.getBody());
            JsonNode features = root.path("features");

            if (features.isArray() && !features.isEmpty()) {
                JsonNode properties = features.get(0).path("properties");

                String formattedAddress = properties.path("formatted").asString(null);
                String street = properties.path("street").asString(null);
                String houseNumber = properties.path("housenumber").asString(null);
                String city = properties.path("city").asString(null);
                String district = properties.path("district").asString(null);
                if (district == null) {
                    district = properties.path("suburb").asString(null);
                }

                String shortAddress = formatShortAddress(street, houseNumber, formattedAddress);
                String subtitle = formatSubtitle(city, district);

                AddressDTO addressDTO = new AddressDTO(shortAddress, subtitle, lat, lon);

                try {
                    String jsonToCache = objectMapper.writeValueAsString(addressDTO);
                    cacheRedis.opsForValue().set(cacheKey, jsonToCache, CACHE_DURATION);
                } catch (Exception e) {
                    log.error("Redis Cache Write Error: {}", e.getMessage(), e);
                }

                return addressDTO;
            } else {
                throw new RuntimeException("No address found for these coordinates");
            }
        } catch (Exception e) {
            OperationTimeoutException.rethrowIfTimeout(e);
            log.error("Geoapify Error: {}", e.getMessage(), e);
            throw new RuntimeException("Failed to fetch address from maps provider");
        }
    }

    public List<AddressDTO> autocompleteAddress(String text) {
        String currentLanguage = validateLanguage(LocaleContextHolder.getLocale().getLanguage());
        String searchText = InputValidation.normalizeAddressSearchText(text);
        String normalizedText = searchText.toLowerCase(Locale.ROOT);

        String cacheKey = "geo:auto:v9:" + normalizedText + ":" + currentLanguage;

        try {
            String cachedValue = cacheRedis.opsForValue().get(cacheKey);
            if (StringUtils.hasText(cachedValue)) {
                return objectMapper.readValue(cachedValue, new TypeReference<List<AddressDTO>>() {});
            }
        } catch (Exception e) {
            log.error("Redis Cache Read Error (Autocomplete): {}", e.getMessage(), e);
        }

        String rectFilter = String.format(
                Locale.US,
                "rect:%f,%f,%f,%f",
                ServiceArea.MIN_LONGITUDE,
                ServiceArea.MIN_LATITUDE,
                ServiceArea.MAX_LONGITUDE,
                ServiceArea.MAX_LATITUDE
        );
        String proximityBias = "proximity:30.5234,50.4451";

        Map<String, String> uriVariables = new HashMap<>();
        uriVariables.put("text", searchText);
        uriVariables.put("lang", currentLanguage);
        uriVariables.put("filter", rectFilter);
        uriVariables.put("bias", proximityBias);
        uriVariables.put("apiKey", geoapifyApiKey);

        String urlTemplate = "https://api.geoapify.com/v1/geocode/autocomplete" +
                "?text={text}&lang={lang}&filter={filter}&filter=countrycode:ua&bias={bias}&limit=5&format=json&apiKey={apiKey}";

        try {
            ResponseEntity<String> response = restTemplate.getForEntity(urlTemplate, String.class, uriVariables);
            JsonNode root = objectMapper.readTree(response.getBody());

            JsonNode resultsArray = root.path("results");

            Map<String, AddressDTO> uniqueMap = new LinkedHashMap<>();

            if (resultsArray.isArray()) {
                for (JsonNode item : resultsArray) {
                    String formattedAddress = item.path("formatted").asString(null);
                    String street = item.path("street").asString(null);
                    String houseNumber = item.path("housenumber").asString(null);
                    String city = item.path("city").asString(null);

                    String district = item.path("district").asString(null);
                    if (district == null) {
                        district = item.path("suburb").asString(null);
                    }

                    double lon = item.path("lon").asDouble();
                    double lat = item.path("lat").asDouble();

                    String shortAddress = formatShortAddress(street, houseNumber, formattedAddress);
                    String subtitle = formatSubtitle(city, district);

                    String uniqueKey = shortAddress + "|" + (city != null ? city : "");

                    AddressDTO newDto = new AddressDTO(shortAddress, subtitle, lat, lon);

                    if (uniqueMap.containsKey(uniqueKey)) {
                        AddressDTO existingDto = uniqueMap.get(uniqueKey);

                        int oldLen = existingDto.getSubtitle() != null ? existingDto.getSubtitle().length() : 0;
                        int newLen = newDto.getSubtitle() != null ? newDto.getSubtitle().length() : 0;

                        if (newLen > oldLen) {
                            uniqueMap.put(uniqueKey, newDto);
                        }
                    } else {
                        uniqueMap.put(uniqueKey, newDto);
                    }
                }
            }

            List<AddressDTO> results = new ArrayList<>(uniqueMap.values());

            try {
                String jsonToCache = objectMapper.writeValueAsString(results);
                cacheRedis.opsForValue().set(cacheKey, jsonToCache, CACHE_DURATION);
            } catch (Exception e) {
                log.error("Redis Cache Write Error: {}", e.getMessage(), e);
            }

            return results;

        } catch (Exception e) {
            OperationTimeoutException.rethrowIfTimeout(e);
            log.error("Geoapify Autocomplete Error: {}", e.getMessage(), e);
            throw new RuntimeException("Failed to fetch address suggestions");
        }
    }

    private String formatShortAddress(String street, String houseNumber, String fullFormatted) {
        String shortAddress;
        if (street != null && houseNumber != null) {
            shortAddress = street + ", " + houseNumber;
        } else if (street != null) {
            shortAddress = street;
        } else {
            shortAddress = fullFormatted != null && !fullFormatted.isEmpty()
                    ? fullFormatted.split(",")[0]
                    : null;
        }
        return InputValidation.normalizeAddressPart(shortAddress);
    }

    private String formatSubtitle(String city, String district) {
        StringBuilder builder = new StringBuilder();
        if (city != null) {
            builder.append(city);
        }
        if (district != null && (city == null || !city.equals(district))) {
            if (!builder.isEmpty()) builder.append(", ");
            builder.append(district);
        }
        return builder.isEmpty() ? null : InputValidation.normalizeAddressPart(builder.toString());
    }

    private String validateLanguage(String lang) {
        if (lang == null || lang.isBlank()) return "en";
        String lower = lang.toLowerCase(Locale.ROOT);
        return (lower.equals("ru") || lower.equals("uk")) ? lower : "en";
    }

    public RouteDTO getRoute(RouteRequestDTO request, UUID accountId) {
        return calculateRoute(request, false, RoutePolicy.PASSENGER_MIN_DISTANCE_METERS,
                () -> rateLimits.carRoute(accountId)).route();
    }

    public RouteDTO getRouteForSearch(RouteRequestDTO request, UUID accountId) {
        return calculateRoute(request, false, RoutePolicy.PASSENGER_MIN_DISTANCE_METERS,
                () -> rateLimits.newSearchWithCarRoute(accountId)).route();
    }

    private CalculatedRoute calculateRoute(RouteRequestDTO request, boolean includeTiming, int minimumDistanceMeters,
                                            Runnable checkQuota) {
        RoutePolicyValidator.validateInput(
                request.getStartLat(),
                request.getStartLon(),
                request.getEndLat(),
                request.getEndLon(),
                request.getWaypoints()
        );

        List<String> points = new ArrayList<>();
        points.add(String.format(Locale.US, "%f,%f", request.getStartLon(), request.getStartLat()));

        if (request.getWaypoints() != null && !request.getWaypoints().isEmpty()) {
            for (TripWaypoint wp : request.getWaypoints()) {
                points.add(String.format(Locale.US, "%f,%f", wp.getLon(), wp.getLat()));
            }
        }

        points.add(String.format(Locale.US, "%f,%f", request.getEndLon(), request.getEndLat()));
        String coordinatesString = String.join(";", points);

        String urlTemplate = osrmUrl + "/route/v1/driving/{coordinates}?overview=full&geometries=polyline";
        if (includeTiming) {
            urlTemplate += "&steps=true&annotations=distance,duration";
        }

        Map<String, String> uriVariables = new HashMap<>();
        uriVariables.put("coordinates", coordinatesString);

        RouteDTO route;
        JsonNode bestRoute;
        checkQuota.run();
        try {
            ResponseEntity<String> response = restTemplate.getForEntity(urlTemplate, String.class, uriVariables);
            JsonNode root = objectMapper.readTree(response.getBody());

            String code = root.path("code").asString();
            if (!"Ok".equals(code)) {
                throw new RuntimeException("OSRM returned error code: " + code);
            }

            JsonNode routes = root.path("routes");

            if (routes.isArray() && !routes.isEmpty()) {
                bestRoute = routes.get(0);

                String polyline = bestRoute.path("geometry").asString();

                double distanceMetersRaw = bestRoute.path("distance").asDouble();
                double durationSecondsRaw = bestRoute.path("duration").asDouble();

                int distanceMeters = (int) Math.round(distanceMetersRaw);
                int durationSeconds = (int) Math.round(durationSecondsRaw);

                route = new RouteDTO(polyline, distanceMeters, durationSeconds);
            } else {
                throw new RuntimeException("No route found between these points");
            }
        } catch (Exception e) {
            OperationTimeoutException.rethrowIfTimeout(e);
            log.error("OSRM Routing Error: {}", e.getMessage(), e);
            throw new RuntimeException("Failed to calculate route via local OSRM");
        }

        RoutePolicyValidator.validateCalculatedRoute(route, minimumDistanceMeters);
        return new CalculatedRoute(route, bestRoute);
    }

    public RouteWithStopsDTO getRouteWithStops(RouteRequestDTO request, UUID accountId) {
        CalculatedRoute calculated = calculateRoute(request, true, RoutePolicy.MIN_DISTANCE_METERS,
                () -> rateLimits.carRoute(accountId));
        RouteDTO baseRoute = calculated.route();
        RouteTimingProfile timing;
        try {
            timing = RouteTimingProfile.from(calculated.osrmRoute());
        } catch (IllegalStateException e) {
            log.error("Invalid OSRM route timing: {}", e.getMessage());
            throw new RuntimeException("Failed to calculate stop arrival times via local OSRM", e);
        }
        String wktPolyline = decodePolylineToWkt(baseRoute.getPolyline());
        OperationDeadline.check();
        List<StopFractionProjection> projections = stopRepository.findStopsWithFraction(wktPolyline, 30.0);
        List<StopOnRouteDTO> stops = new ArrayList<>();

        for (StopFractionProjection p : projections) {
            int stopDistance = (int) Math.round(baseRoute.getDistanceMeters() * p.getRouteFraction());
            int stopEta = timing.etaSeconds(p.getRouteFraction());

            stops.add(new StopOnRouteDTO(
                    p.getId(),
                    p.getName(),
                    p.getLat(),
                    p.getLon(),
                    stopEta,
                    stopDistance
            ));
        }

        return new RouteWithStopsDTO(baseRoute, stops);
    }

    private record CalculatedRoute(RouteDTO route, JsonNode osrmRoute) {
    }

    private String decodePolylineToWkt(String encoded) {
        List<double[]> poly = new ArrayList<>();
        int index = 0, len = encoded.length();
        int lat = 0, lng = 0;

        while (index < len) {
            int b, shift = 0, result = 0;
            do {
                b = encoded.charAt(index++) - 63;
                result |= (b & 0x1f) << shift;
                shift += 5;
            } while (b >= 0x20);
            int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
            lat += dlat;

            shift = 0; result = 0;
            do {
                b = encoded.charAt(index++) - 63;
                result |= (b & 0x1f) << shift;
                shift += 5;
            } while (b >= 0x20);
            int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
            lng += dlng;

            poly.add(new double[]{lng / 1E5, lat / 1E5});
        }

        StringBuilder wkt = new StringBuilder("LINESTRING(");
        for (int i = 0; i < poly.size(); i++) {
            wkt.append(poly.get(i)[0]).append(" ").append(poly.get(i)[1]);
            if (i < poly.size() - 1) {
                wkt.append(", ");
            }
        }
        wkt.append(")");

        return wkt.toString();
    }
}
