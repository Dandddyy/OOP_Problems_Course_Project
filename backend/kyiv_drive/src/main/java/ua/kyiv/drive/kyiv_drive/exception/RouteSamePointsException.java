package ua.kyiv.drive.kyiv_drive.exception;

public class RouteSamePointsException extends IllegalArgumentException {
    public RouteSamePointsException() {
        super("Start and end locations cannot be the exact same point");
    }
}
