package ua.kyiv.drive.kyiv_drive.config;

import jakarta.validation.constraints.AssertTrue;
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
@ConfigurationProperties(prefix = "app.security.password-reset")
public class PasswordResetProperties {

    @NotNull
    private Duration tokenTtl = Duration.ofMinutes(10);

    @AssertTrue(message = "Password reset token TTL must be positive")
    public boolean isValid() {
        return tokenTtl != null && !tokenTtl.isZero() && !tokenTtl.isNegative();
    }
}
