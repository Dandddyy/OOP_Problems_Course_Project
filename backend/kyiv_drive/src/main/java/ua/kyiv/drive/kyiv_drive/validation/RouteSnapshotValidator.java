package ua.kyiv.drive.kyiv_drive.validation;

import ua.kyiv.drive.kyiv_drive.dto.map.RouteWithStopsDTO;

import java.util.List;
import java.util.Objects;
import java.util.UUID;

public final class RouteSnapshotValidator {

    private RouteSnapshotValidator() {
        throw new IllegalStateException("Utility class");
    }

    public static boolean matches(
            String expectedPolyline,
            Integer expectedDistanceMeters,
            Integer expectedDurationSeconds,
            List<UUID> expectedStopIds,
            RouteWithStopsDTO actualSnapshot
    ) {
        if (actualSnapshot == null || actualSnapshot.getRoute() == null) {
            return false;
        }
        if (!Objects.equals(expectedPolyline, actualSnapshot.getRoute().getPolyline())) {
            return false;
        }
        if (!metricsMatch(
                expectedDistanceMeters,
                expectedDurationSeconds,
                actualSnapshot.getRoute().getDistanceMeters(),
                actualSnapshot.getRoute().getDurationSeconds()
        )) {
            return false;
        }

        List<UUID> actualStopIds = actualSnapshot.getStops() == null
                ? List.of()
                : actualSnapshot.getStops().stream().map(stop -> stop.getStopId()).toList();

        return Objects.equals(expectedStopIds, actualStopIds);
    }

    public static boolean metricsMatch(
            Integer expectedDistanceMeters,
            Integer expectedDurationSeconds,
            int actualDistanceMeters,
            int actualDurationSeconds
    ) {
        return withinTolerance(
                expectedDistanceMeters,
                actualDistanceMeters,
                RoutePolicy.DISTANCE_ABSOLUTE_TOLERANCE_METERS,
                RoutePolicy.DISTANCE_RELATIVE_TOLERANCE
        ) && withinTolerance(
                expectedDurationSeconds,
                actualDurationSeconds,
                RoutePolicy.DURATION_ABSOLUTE_TOLERANCE_SECONDS,
                RoutePolicy.DURATION_RELATIVE_TOLERANCE
        );
    }

    private static boolean withinTolerance(
            Integer expected,
            int actual,
            int absoluteTolerance,
            double relativeTolerance
    ) {
        if (expected == null) {
            return false;
        }

        long difference = Math.abs((long) expected - actual);
        long relativeLimit = (long) Math.ceil(Math.abs((long) expected) * relativeTolerance);
        return difference <= Math.max(absoluteTolerance, relativeLimit);
    }
}
