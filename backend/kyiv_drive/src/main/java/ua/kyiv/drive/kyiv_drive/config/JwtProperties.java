package ua.kyiv.drive.kyiv_drive.config;

import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.Valid;
import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Component;
import org.springframework.validation.annotation.Validated;

import java.time.Duration;
import java.util.ArrayList;
import java.util.List;

@Getter
@Setter
@Component
@Validated
@ConfigurationProperties(prefix = "app.security.tokens")
public class JwtProperties {

    @NotBlank
    private String issuer = "kyiv-drive";

    @NotBlank
    private String accessAudience = "kyiv-drive-api";

    @NotBlank
    private String refreshAudience = "kyiv-drive-refresh";

    @NotNull
    private Duration accessTtl = Duration.ofMinutes(15);

    @NotNull
    private Duration clockSkew = Duration.ofSeconds(60);

    @Valid
    @NotNull
    private KeyRing access = new KeyRing("access-v1");

    @Valid
    @NotNull
    private KeyRing refresh = new KeyRing("refresh-v1");

    @AssertTrue(message = "JWT durations must be positive")
    public boolean isDurationConfigurationValid() {
        return isPositive(accessTtl) && isPositive(clockSkew);
    }

    @AssertTrue(message = "Access and refresh JWT key ids must be different")
    public boolean isKeyIdConfigurationValid() {
        return access == null
                || refresh == null
                || access.getActiveKeyId() == null
                || refresh.getActiveKeyId() == null
                || !access.getActiveKeyId().equals(refresh.getActiveKeyId());
    }

    private boolean isPositive(Duration duration) {
        return duration != null && !duration.isZero() && !duration.isNegative();
    }

    @Getter
    @Setter
    public static class KeyRing {

        @NotBlank
        private String activeKeyId;

        @NotEmpty
        private List<@Valid KeyDefinition> keys = new ArrayList<>();

        public KeyRing() {
        }

        public KeyRing(String activeKeyId) {
            this.activeKeyId = activeKeyId;
        }
    }

    @Getter
    @Setter
    public static class KeyDefinition {

        @NotBlank
        private String id;

        @NotNull
        private Resource publicKeyLocation;

        private Resource privateKeyLocation;
    }
}
