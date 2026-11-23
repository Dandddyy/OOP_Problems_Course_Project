package ua.kyiv.drive.kyiv_drive.config;

import jakarta.validation.constraints.AssertTrue;
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
@ConfigurationProperties(prefix = "app.trip-search.cache")
public class SearchCacheProperties {
    @NotBlank
    private String host = "localhost";
    @Min(1)
    @Max(65535)
    private int port = 6380;
    private String username = "";
    private String password = "";
    private Duration commandTimeout = Duration.ofSeconds(1);
    private Duration walkingTtl = Duration.ofDays(7);
    private Duration noRouteTtl = Duration.ofMinutes(10);
    private Duration snapshotTtl = Duration.ofMinutes(5);
    @Min(1) @Max(10)
    private int maxVariants = 3;
    @Min(1) @Max(10)
    private int keepAlivesPerMinute = 2;

    @AssertTrue(message = "Search cache timeouts and TTLs must be positive")
    public boolean isDurationConfigurationValid() {
        return positive(commandTimeout) && positive(walkingTtl)
                && positive(noRouteTtl) && positive(snapshotTtl);
    }

    private static boolean positive(Duration value) {
        return value != null && value.compareTo(Duration.ZERO) > 0;
    }
}
