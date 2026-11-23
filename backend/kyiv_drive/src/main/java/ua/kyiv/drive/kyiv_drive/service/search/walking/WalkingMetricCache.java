package ua.kyiv.drive.kyiv_drive.service.search.walking;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.dao.DataAccessException;
import org.springframework.data.redis.connection.SetCondition;
import org.springframework.data.redis.core.RedisCallback;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.types.Expiration;
import org.springframework.stereotype.Component;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.ObjectMapper;
import ua.kyiv.drive.kyiv_drive.config.SearchCacheProperties;
import ua.kyiv.drive.kyiv_drive.model.search.WalkingMetric;

import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Slf4j
@Component
public class WalkingMetricCache {
    private final StringRedisTemplate redis;
    private final SearchCacheProperties properties;
    private final ObjectMapper mapper;

    public WalkingMetricCache(@Qualifier("searchCacheRedisTemplate") StringRedisTemplate redis,
                              SearchCacheProperties properties, ObjectMapper mapper) {
        this.redis = redis;
        this.properties = properties;
        this.mapper = mapper;
    }

    public Map<String, WalkingMetric> read(Collection<String> requestedKeys) {
        List<String> keys = List.copyOf(requestedKeys);
        if (keys.isEmpty()) return Map.of();
        List<String> values;
        try {
            values = redis.opsForValue().multiGet(keys);
        } catch (DataAccessException e) {
            log.warn("Walking cache read unavailable; calculating routes directly");
            return Map.of();
        }
        if (values == null || values.size() != keys.size()) return Map.of();
        Map<String, WalkingMetric> result = new HashMap<>();
        for (int i = 0; i < values.size(); i++) {
            if (values.get(i) == null) continue;
            try {
                var json = mapper.readTree(values.get(i));
                if (!json.isObject() || !json.path("reachable").isBoolean()
                        || !json.path("distanceMeters").isNumber() || !json.path("durationSeconds").isNumber()) {
                    continue;
                }
                WalkingMetric metric = mapper.readValue(values.get(i), WalkingMetric.class);
                if (metric != null && finiteNonNegative(metric.distanceMeters())
                        && finiteNonNegative(metric.durationSeconds())) result.put(keys.get(i), metric);
            } catch (JacksonException | IllegalArgumentException e) {
                log.warn("Ignoring an invalid walking cache entry");
            }
        }
        return result;
    }

    public void write(Map<String, WalkingMetric> metrics) {
        if (metrics.isEmpty()) return;
        Map<String, byte[]> values = new HashMap<>();
        metrics.forEach((key, value) -> values.put(key, mapper.writeValueAsBytes(value)));
        try {
            redis.executePipelined((RedisCallback<Object>) connection -> {
                metrics.forEach((key, metric) -> {
                    Duration ttl = metric.reachable() ? properties.getWalkingTtl() : properties.getNoRouteTtl();
                    connection.stringCommands().set(key.getBytes(StandardCharsets.UTF_8), values.get(key),
                            SetCondition.upsert(), Expiration.milliseconds(ttl.toMillis()));
                });
                return null;
            });
        } catch (DataAccessException e) {
            log.warn("Walking cache write unavailable; returning calculated routes without caching");
        }
    }

    private static boolean finiteNonNegative(double value) {
        return Double.isFinite(value) && value >= 0;
    }
}
