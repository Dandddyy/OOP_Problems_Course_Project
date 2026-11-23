package ua.kyiv.drive.kyiv_drive.exception;

import lombok.Getter;
import org.springframework.http.HttpStatus;

@Getter
public class RateLimitException extends RuntimeException {
    private final String code;
    private final HttpStatus status;

    public RateLimitException(String code) {
        this(code, HttpStatus.TOO_MANY_REQUESTS, null);
    }

    private RateLimitException(String code, HttpStatus status, Throwable cause) {
        super(code, cause);
        this.code = code;
        this.status = status;
    }

    public static RateLimitException unavailable(Throwable cause) {
        return new RateLimitException("rate_limit_unavailable", HttpStatus.SERVICE_UNAVAILABLE, cause);
    }
}
