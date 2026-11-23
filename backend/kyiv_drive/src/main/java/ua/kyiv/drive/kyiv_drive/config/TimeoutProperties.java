package ua.kyiv.drive.kyiv_drive.config;

import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;
import org.springframework.validation.annotation.Validated;

import java.time.Duration;
import java.util.stream.Stream;

@Getter
@Setter
@Validated
@Component
@ConfigurationProperties("app.timeouts")
public class TimeoutProperties {
    private Duration standard = Duration.ofSeconds(10);
    private Duration route = Duration.ofSeconds(15);
    private Duration search = Duration.ofSeconds(30);
    private Duration recalculate = Duration.ofSeconds(15);
    private Duration stopImport = Duration.ofSeconds(60);
    @Min(1) @Max(Integer.MAX_VALUE) private long sqlStandardMs = 5_000;
    @Min(1) @Max(Integer.MAX_VALUE) private long sqlHeavyMs = 10_000;
    private Duration carOsrmConnect = Duration.ofSeconds(1);
    private Duration carOsrmResponse = Duration.ofSeconds(3);
    private Duration geoapifyConnect = Duration.ofSeconds(2);
    private Duration geoapifyResponse = Duration.ofSeconds(5);
    private Duration brevoConnect = Duration.ofSeconds(2);
    private Duration brevoTotal = Duration.ofSeconds(8);

    @AssertTrue(message = "Timeouts must be positive and at least one millisecond")
    public boolean isValid() {
        return Stream.of(standard, route, search, recalculate, stopImport,
                        carOsrmConnect, carOsrmResponse, geoapifyConnect, geoapifyResponse, brevoConnect, brevoTotal)
                .allMatch(value -> value != null && value.compareTo(Duration.ofMillis(1)) >= 0);
    }
}
