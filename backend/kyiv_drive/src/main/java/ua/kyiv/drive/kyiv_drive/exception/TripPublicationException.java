package ua.kyiv.drive.kyiv_drive.exception;

import lombok.Getter;
import org.springframework.http.HttpStatus;

import java.util.Set;

@Getter
public class TripPublicationException extends RuntimeException {
    private static final Set<String> USER_FACING_CODES = Set.of(
            "trip_driver_required", "trip_car_unavailable", "trip_active_limit_reached",
            "trip_duplicate", "trip_departure_in_past"
    );

    private final String code;
    private final HttpStatus status;
    private final Object[] arguments;

    public TripPublicationException(String code, HttpStatus status, Object... arguments) {
        super(code);
        this.code = code;
        this.status = status;
        this.arguments = arguments;
    }

    /** Only failures that valid client input cannot prevent are localized for display. */
    public boolean isUserFacing() {
        return USER_FACING_CODES.contains(code);
    }
}
