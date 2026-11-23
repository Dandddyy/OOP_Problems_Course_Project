package ua.kyiv.drive.kyiv_drive.config;

import jakarta.validation.Valid;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotEmpty;
import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;
import org.springframework.validation.annotation.Validated;

import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Objects;

@Getter
@Setter
@Validated
@Component
@ConfigurationProperties("app.execution")
public class ExecutionProperties {
    @Valid @NotEmpty
    private Map<String, Pool> pools = new LinkedHashMap<>(Map.of(
            "trip_search", new Pool(),
            "car_routing", new Pool(),
            "stop_import", new Pool()
    ));

    public Map<String, PoolLimits> resolvedPools() {
        Map<String, PoolLimits> resolved = new LinkedHashMap<>();
        pools.forEach((name, pool) -> {
            int workers = Objects.requireNonNullElse(pool.getWorkers(), "stop_import".equals(name) ? 1 : 4);
            int capacity = Objects.requireNonNullElse(pool.getQueueCapacity(), switch (name) {
                case "trip_search", "car_routing" -> 16;
                case "stop_import" -> 2;
                default -> 32;
            });
            resolved.put(name, new PoolLimits(workers, capacity, pool.getQueueWait()));
        });
        return resolved;
    }

    public record PoolLimits(int workers, int queueCapacity, Duration queueWait) {}

    @Getter
    @Setter
    public static class Pool {
        @Min(1) @Max(64) private Integer workers;
        @Min(0) @Max(256) private Integer queueCapacity;
        private Duration queueWait = Duration.ofSeconds(3);

        @AssertTrue(message = "Queue wait must be between zero and ten seconds")
        public boolean isQueueWaitValid() {
            return queueWait != null && !queueWait.isNegative() && queueWait.compareTo(Duration.ofSeconds(10)) <= 0;
        }
    }
}
