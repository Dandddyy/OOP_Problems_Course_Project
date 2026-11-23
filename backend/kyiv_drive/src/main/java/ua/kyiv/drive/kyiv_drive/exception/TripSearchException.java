package ua.kyiv.drive.kyiv_drive.exception;

import lombok.Getter;
import org.springframework.http.HttpStatus;

@Getter
public class TripSearchException extends RuntimeException {
    private final String code;
    private final HttpStatus status;

    public TripSearchException(String code, HttpStatus status) {
        super(code);
        this.code = code;
        this.status = status;
    }

    public TripSearchException(String code, HttpStatus status, Throwable cause) {
        super(code, cause);
        this.code = code;
        this.status = status;
    }
}
