package ua.kyiv.drive.kyiv_drive.service;

import org.springframework.stereotype.Component;
import ua.kyiv.drive.kyiv_drive.dto.trip.CreateTripWrapperDTO;
import ua.kyiv.drive.kyiv_drive.dto.trip.TripCreateDTO;
import ua.kyiv.drive.kyiv_drive.dto.trip.TripStopCreateDTO;
import ua.kyiv.drive.kyiv_drive.entity.Trip;
import ua.kyiv.drive.kyiv_drive.entity.TripStop;
import ua.kyiv.drive.kyiv_drive.entity.TripWaypoint;
import ua.kyiv.drive.kyiv_drive.exception.IdempotencyConflictException;
import ua.kyiv.drive.kyiv_drive.validation.RouteSnapshotValidator;

import java.util.List;
import java.util.Objects;

@Component
public class TripRequestMatcher {
    public boolean isDuplicate(Trip existing, TripCreateDTO submitted) {
        return existing.getStartLocation() != null && existing.getEndLocation() != null
                && Objects.equals(existing.getCarId(), submitted.getCarId())
                && sameDouble(existing.getStartLocation().getY(), submitted.getStartLat())
                && sameDouble(existing.getStartLocation().getX(), submitted.getStartLon())
                && sameDouble(existing.getEndLocation().getY(), submitted.getEndLat())
                && sameDouble(existing.getEndLocation().getX(), submitted.getEndLon())
                && Objects.equals(waypoints(existing.getWaypoints()), waypoints(submitted.getWaypoints()))
                && existing.getScheduleType() == submitted.getScheduleType()
                && Objects.equals(existing.getFirstDepartureDate(), submitted.getFirstDepartureDate())
                && Objects.equals(existing.getDepartureLocalTime(), submitted.getDepartureLocalTime())
                && existing.isMonday() == submitted.isMonday()
                && existing.isTuesday() == submitted.isTuesday()
                && existing.isWednesday() == submitted.isWednesday()
                && existing.isThursday() == submitted.isThursday()
                && existing.isFriday() == submitted.isFriday()
                && existing.isSaturday() == submitted.isSaturday()
                && existing.isSunday() == submitted.isSunday();
    }

    public void requireSameRequest(Trip existing, CreateTripWrapperDTO request) {
        TripCreateDTO submitted = request.getTrip();
        if (submitted == null || !isDuplicate(existing, submitted)
                || !Objects.equals(existing.getStartShortAddress(), submitted.getStartShortAddress())
                || !Objects.equals(existing.getStartSubtitle(), submitted.getStartSubtitle())
                || !Objects.equals(existing.getEndShortAddress(), submitted.getEndShortAddress())
                || !Objects.equals(existing.getEndSubtitle(), submitted.getEndSubtitle())
                || !Objects.equals(existing.getRoutePolyline(), submitted.getRoutePolyline())
                || !RouteSnapshotValidator.metricsMatch(submitted.getTotalDistanceMeters(),
                        submitted.getTotalDurationSeconds(), existing.getTotalDistanceMeters(),
                        existing.getTotalDurationSeconds())
                || existing.getPricingType() != submitted.getPricingType()
                || submitted.getPriceAmount() == null
                || existing.getPriceAmount().compareTo(submitted.getPriceAmount()) != 0
                || !Objects.equals(existing.isNegotiationAllowed(), submitted.getNegotiationAllowed())
                || !Objects.equals(existing.getDescription(), submitted.getDescription())
                || !sameStops(existing.getTripStops(), request.getStops() == null ? List.of() : request.getStops())) {
            throw new IdempotencyConflictException();
        }
    }

    private boolean sameStops(List<TripStop> existing, List<TripStopCreateDTO> submitted) {
        if (existing.size() != submitted.size()) {
            return false;
        }
        for (int index = 0; index < existing.size(); index++) {
            if (!Objects.equals(existing.get(index).getStop().getId(), submitted.get(index).getStopId())
                    || !Objects.equals(existing.get(index).getIsEnabled(), submitted.get(index).getIsEnabled())) {
                return false;
            }
        }
        return true;
    }

    private boolean sameDouble(double existing, Double submitted) {
        return submitted != null && Double.compare(existing, submitted) == 0;
    }

    private List<TripWaypoint> waypoints(List<TripWaypoint> value) {
        return value == null ? List.of() : value;
    }
}
