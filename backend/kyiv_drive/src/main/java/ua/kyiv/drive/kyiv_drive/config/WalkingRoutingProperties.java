package ua.kyiv.drive.kyiv_drive.config;

import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

import java.time.Duration;

@Getter
@Setter
@Validated
@ConfigurationProperties(prefix = "app.trip-search.walking")
public class WalkingRoutingProperties {
    @NotBlank
    private String url = "http://localhost:5002";
    // Outside a local checkout, deployment must supply an immutable build revision.
    private String graphRevision = "";
    private String expectedDataVersion = "";
    private String manifestPath = "";
    @Min(1)
    @Max(500)
    private int batchSize = 500;
    @Min(1)
    @Max(8)
    private int parallelism = 2;
    @Min(1)
    @Max(128)
    private int queueCapacity = 32;
    private Duration connectTimeout = Duration.ofSeconds(1);
    private Duration readTimeout = Duration.ofSeconds(3);
    private Duration calculationTimeout = Duration.ofSeconds(30);
    @DecimalMin("0")
    @DecimalMax("1000")
    private double snapRadiusMeters = 100;
    @DecimalMin(value = "0", inclusive = false)
    private double connectorSecondsPerMeter = 0.72;

    @AssertTrue(message = "Walking routing timeouts must be positive")
    public boolean isDurationConfigurationValid() {
        return positive(connectTimeout) && positive(readTimeout) && positive(calculationTimeout);
    }

    private static boolean positive(Duration value) {
        return value != null && value.compareTo(Duration.ZERO) > 0;
    }
}
