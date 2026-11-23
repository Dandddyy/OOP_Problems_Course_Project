package ua.kyiv.drive.kyiv_drive.validation;

import ua.kyiv.drive.kyiv_drive.entity.TripWaypoint;
import ua.kyiv.drive.kyiv_drive.exception.RouteSamePointsException;

import java.util.List;

public final class RouteWaypointValidator {

    private RouteWaypointValidator() {
        throw new IllegalStateException("Utility class");
    }

    public static void validate(
            Double startLat,
            Double startLon,
            Double endLat,
            Double endLon,
            List<TripWaypoint> waypoints
    ) {
        if (samePoint(startLat, startLon, endLat, endLon)) {
            throw new RouteSamePointsException();
        }

        if (waypoints == null || waypoints.isEmpty()) {
            return;
        }

        TripWaypoint firstWaypoint = waypoints.getFirst();
        if (samePoint(startLat, startLon, firstWaypoint.getLat(), firstWaypoint.getLon())) {
            throw new IllegalArgumentException("The first waypoint cannot be the same as the start location");
        }

        TripWaypoint lastWaypoint = waypoints.getLast();
        if (samePoint(lastWaypoint.getLat(), lastWaypoint.getLon(), endLat, endLon)) {
            throw new IllegalArgumentException("The last waypoint cannot be the same as the destination");
        }

        for (int index = 1; index < waypoints.size(); index++) {
            TripWaypoint previous = waypoints.get(index - 1);
            TripWaypoint current = waypoints.get(index);
            if (samePoint(previous.getLat(), previous.getLon(), current.getLat(), current.getLon())) {
                throw new IllegalArgumentException(
                        "Adjacent waypoints " + index + " and " + (index + 1) + " cannot have identical coordinates"
                );
            }
        }
    }

    private static boolean samePoint(Double firstLat, Double firstLon, Double secondLat, Double secondLon) {
        return firstLat != null
                && firstLon != null
                && secondLat != null
                && secondLon != null
                && Double.compare(firstLat, secondLat) == 0
                && Double.compare(firstLon, secondLon) == 0;
    }
}
