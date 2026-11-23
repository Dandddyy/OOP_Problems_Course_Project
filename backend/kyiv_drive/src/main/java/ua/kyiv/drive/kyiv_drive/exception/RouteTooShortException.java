package ua.kyiv.drive.kyiv_drive.exception;

import lombok.Getter;

@Getter
public class RouteTooShortException extends IllegalArgumentException {

    private final int minimumDistanceMeters;

    public RouteTooShortException(int minimumDistanceMeters) {
        super("Route distance must be at least " + minimumDistanceMeters + " meters");
        this.minimumDistanceMeters = minimumDistanceMeters;
    }
}
