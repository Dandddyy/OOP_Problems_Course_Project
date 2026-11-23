package ua.kyiv.drive.kyiv_drive.config;

import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;
import org.springframework.validation.annotation.Validated;

import java.time.Duration;

@Getter
@Setter
@Component
@Validated
@ConfigurationProperties(prefix = "app.security.sessions")
public class SessionProperties {

    @NotNull
    private Duration refreshIdleTtl = Duration.ofDays(7);

    @Min(1)
    private int maxActiveSessions = 10;

    @AssertTrue(message = "Session refresh idle TTL must be positive")
    public boolean isValid() {
        return refreshIdleTtl != null
                && !refreshIdleTtl.isZero()
                && !refreshIdleTtl.isNegative();
    }
}
