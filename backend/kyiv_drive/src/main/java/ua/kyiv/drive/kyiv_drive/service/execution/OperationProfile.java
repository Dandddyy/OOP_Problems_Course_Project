package ua.kyiv.drive.kyiv_drive.service.execution;

import ua.kyiv.drive.kyiv_drive.config.TimeoutProperties;

import java.time.Duration;

public enum OperationProfile {
    STANDARD(null),
    SEARCH("trip_search"),
    RECALCULATE("trip_search"),
    ROUTE("car_routing"),
    STOP_IMPORT("stop_import");

    private final String pool;

    OperationProfile(String pool) { this.pool = pool; }

    public String pool() { return pool; }

    public Duration budget(TimeoutProperties properties) {
        return switch (this) {
            case STANDARD -> properties.getStandard();
            case SEARCH -> properties.getSearch();
            case RECALCULATE -> properties.getRecalculate();
            case ROUTE -> properties.getRoute();
            case STOP_IMPORT -> properties.getStopImport();
        };
    }

    public Duration sqlLimit(TimeoutProperties properties) {
        return Duration.ofMillis(this == STANDARD ? properties.getSqlStandardMs() : properties.getSqlHeavyMs());
    }
}
