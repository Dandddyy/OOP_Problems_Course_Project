package ua.kyiv.drive.kyiv_drive.validation;

public final class RoutePolicy {

    public static final int MAX_WAYPOINTS = 15;
    public static final int MIN_DISTANCE_METERS = 1_000;
    public static final int PASSENGER_MIN_DISTANCE_METERS = 500;
    public static final int MAX_DISTANCE_METERS = 500_000;
    public static final int MAX_POLYLINE_LENGTH = 100_000;
    public static final int MAX_STOPS = 200;
    public static final int DISTANCE_ABSOLUTE_TOLERANCE_METERS = 100;
    public static final double DISTANCE_RELATIVE_TOLERANCE = 0.02;
    public static final int DURATION_ABSOLUTE_TOLERANCE_SECONDS = 120;
    public static final double DURATION_RELATIVE_TOLERANCE = 0.10;

    private RoutePolicy() {
        throw new IllegalStateException("Utility class");
    }
}
