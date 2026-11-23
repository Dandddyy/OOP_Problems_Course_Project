package ua.kyiv.drive.kyiv_drive.model.search;

public record WalkingMetric(boolean reachable, double distanceMeters, double durationSeconds) {
    public static WalkingMetric unreachable() {
        return new WalkingMetric(false, 0, 0);
    }
}
