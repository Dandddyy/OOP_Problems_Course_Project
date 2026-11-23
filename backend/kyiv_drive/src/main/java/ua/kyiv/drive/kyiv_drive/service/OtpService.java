package ua.kyiv.drive.kyiv_drive.service;

import lombok.RequiredArgsConstructor;
import org.springframework.context.MessageSource;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.data.redis.core.script.RedisScript;
import org.springframework.stereotype.Service;
import ua.kyiv.drive.kyiv_drive.config.RequestRateLimitProperties;
import ua.kyiv.drive.kyiv_drive.exception.FieldValidationException;
import ua.kyiv.drive.kyiv_drive.exception.OperationTimeoutException;
import ua.kyiv.drive.kyiv_drive.exception.OtpException;
import ua.kyiv.drive.kyiv_drive.exception.RateLimitException;
import ua.kyiv.drive.kyiv_drive.service.limit.RedisRateLimiter;
import ua.kyiv.drive.kyiv_drive.service.limit.RequestRateLimits;

import java.security.SecureRandom;
import java.time.Duration;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class OtpService {

    private static final RedisScript<Long> OTP_STATE = RedisRateLimiter.script("otp_state.lua");
    private static final Duration OTP_TTL = Duration.ofMinutes(5);
    private static final long OTP_MISSING = 0;
    private static final long OTP_MATCHED = 1;
    private static final long OTP_ATTEMPTS_EXHAUSTED = -2;

    private final BrevoEmailService brevoEmailService;
    private final RedisRateLimiter rateLimiter;
    private final RequestRateLimits limits;
    private final RequestRateLimitProperties rateProperties;
    private final MessageSource messageSource;
    private final SecureRandom secureRandom = new SecureRandom();

    public void sendCode(String email) {
        var reservation = limits.otpSendEmail(email);
        String code = generateCode();
        String issued = UUID.randomUUID() + ":" + code;
        List<String> keys = otpKeys(email);

        try {
            rateLimiter.execute(OTP_STATE, keys, "issue", issued, Long.toString(OTP_TTL.toMillis()));
            brevoEmailService.sendOtpCode(email, code, LocaleContextHolder.getLocale());
        } catch (RuntimeException e) {
            try {
                rateLimiter.execute(OTP_STATE, keys, "discard", issued);
                rateLimiter.refund(reservation);
            } catch (RateLimitException cleanupError) {
                e.addSuppressed(cleanupError);
            }
            if (e instanceof RateLimitException rateFailure) throw rateFailure;
            if (e instanceof OperationTimeoutException timeout) throw timeout;
            throw new RuntimeException("Failed to send email with code", e);
        }
    }

    public void validateCode(String email, String userCode) {
        long result = rateLimiter.execute(OTP_STATE, otpKeys(email), "verify", userCode,
                Integer.toString(rateProperties.getOtpVerificationAttempts()));
        if (result == OTP_ATTEMPTS_EXHAUSTED) {
            throw new RateLimitException("too_many_incorrect_code_attempts");
        }
        if (result == OTP_MISSING) {
            throw new OtpException(getMessage("error.code_expired"));
        }
        if (result != OTP_MATCHED) {
            throw new FieldValidationException("code", getMessage("error.invalid_code"));
        }
    }

    private List<String> otpKeys(String email) {
        return List.of("otp:" + email, "rate:verify:" + email);
    }

    private String generateCode() {
        return String.valueOf(100000 + secureRandom.nextInt(900000));
    }

    private String getMessage(String code) {
        return messageSource.getMessage(code, null, LocaleContextHolder.getLocale());
    }
}
