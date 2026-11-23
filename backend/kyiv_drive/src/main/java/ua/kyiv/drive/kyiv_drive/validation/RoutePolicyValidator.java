package ua.kyiv.drive.kyiv_drive.validation;

import ua.kyiv.drive.kyiv_drive.dto.map.RouteDTO;
import ua.kyiv.drive.kyiv_drive.entity.TripWaypoint;
import ua.kyiv.drive.kyiv_drive.exception.RouteTooLongException;
import ua.kyiv.drive.kyiv_drive.exception.RouteTooShortException;

import java.util.List;

public final class RoutePolicyValidator {

    private RoutePolicyValidator() {
        throw new IllegalStateException("Utility class");
    }

    /** Route business rules for points already checked by the request DTO constraints. */
    public static void validateInput(
            Double startLat,
            Double startLon,
            Double endLat,
            Double endLon,
            List<TripWaypoint> waypoints
    ) {
        requirePointInServiceArea(startLat, startLon, "Start location");
        requirePointInServiceArea(endLat, endLon, "Destination");

        if (waypoints != null) {
            for (int index = 0; index < waypoints.size(); index++) {
                TripWaypoint waypoint = waypoints.get(index);
                requirePointInServiceArea(
                        waypoint.getLat(),
                        waypoint.getLon(),
                        "Waypoint " + (index + 1)
                );
            }
        }

        RouteWaypointValidator.validate(startLat, startLon, endLat, endLon, waypoints);
    }

    public static void validateCalculatedRoute(RouteDTO route) {
        validateCalculatedRoute(route, RoutePolicy.MIN_DISTANCE_METERS);
    }

    public static void validateCalculatedRoute(RouteDTO route, int minimumDistanceMeters) {
        if (route == null || route.getPolyline() == null || route.getPolyline().isBlank()) {
            throw new IllegalArgumentException("The routing provider returned an empty route");
        }
        if (route.getDistanceMeters() < minimumDistanceMeters) {
            throw new RouteTooShortException(minimumDistanceMeters);
        }
        if (route.getDistanceMeters() > RoutePolicy.MAX_DISTANCE_METERS) {
            throw new RouteTooLongException(RoutePolicy.MAX_DISTANCE_METERS);
        }
    }

    private static void requirePointInServiceArea(Double lat, Double lon, String pointName) {
        if (!ServiceArea.contains(lat, lon)) {
            throw new IllegalArgumentException(pointName + " is outside the service area");
        }
    }
}
