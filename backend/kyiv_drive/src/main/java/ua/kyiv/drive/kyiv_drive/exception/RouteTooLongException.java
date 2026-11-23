package ua.kyiv.drive.kyiv_drive.exception;

import lombok.Getter;

@Getter
public class RouteTooLongException extends IllegalArgumentException {

    private final int maximumDistanceMeters;

    public RouteTooLongException(int maximumDistanceMeters) {
        super("Route distance cannot exceed " + maximumDistanceMeters + " meters");
        this.maximumDistanceMeters = maximumDistanceMeters;
    }
}
