package ua.kyiv.drive.kyiv_drive.config;

import jakarta.validation.constraints.Min;
import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;
import org.springframework.validation.annotation.Validated;

@Getter
@Setter
@Validated
@Component
@ConfigurationProperties("app.rate-limit")
public class RequestRateLimitProperties {
    @Min(1) private int accountPerMinute = 300;
    @Min(1) private int accountBurst = 30;
    @Min(1) private int publicPerMinute = 120;
    @Min(1) private int publicBurst = 20;
    @Min(1) private int loginPerIpPerMinute = 20;
    @Min(1) private int otpSendPerIpPerFifteenMinutes = 20;
    @Min(1) private int otpSendPerEmailPerFifteenMinutes = 3;
    @Min(1) private int failedLoginsPerEmail = 5;
    @Min(1) private int otpVerificationAttempts = 5;
    @Min(1) private int carRoutesPerAccountPerMinute = 30;
}
