package ua.kyiv.drive.kyiv_drive.validation;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import ua.kyiv.drive.kyiv_drive.dto.trip.CreateTripWrapperDTO;
import ua.kyiv.drive.kyiv_drive.dto.trip.TripCreateDTO;
import ua.kyiv.drive.kyiv_drive.dto.trip.TripStopCreateDTO;
import ua.kyiv.drive.kyiv_drive.entity.TripPricingType;
import ua.kyiv.drive.kyiv_drive.entity.TripScheduleType;
import ua.kyiv.drive.kyiv_drive.exception.TripPublicationException;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.HashSet;
import java.util.List;
import java.util.UUID;

/** Publication business rules applied after DTO constraint validation. */
@Component
public class TripRequestValidator {
    public void validate(CreateTripWrapperDTO request, Instant now) {
        TripCreateDTO trip = request.getTrip();
        RoutePolicyValidator.validateInput(trip.getStartLat(), trip.getStartLon(),
                trip.getEndLat(), trip.getEndLon(), trip.getWaypoints());
        validatePrice(trip);
        validateSchedule(trip, now);
        List<TripStopCreateDTO> stops = request.getStops() == null ? List.of() : request.getStops();
        HashSet<UUID> ids = new HashSet<>();
        for (TripStopCreateDTO stop : stops) {
            if (!ids.add(stop.getStopId())) {
                throw new IllegalArgumentException("Route stops cannot contain duplicate IDs");
            }
        }
    }

    private void validatePrice(TripCreateDTO trip) {
        BigDecimal maximum = trip.getPricingType() == TripPricingType.FIXED
                ? TripPolicy.FIXED_PRICE_UPPER_BOUND : TripPolicy.PER_KM_PRICE_UPPER_BOUND;
        BigDecimal price = trip.getPriceAmount();
        if (price.compareTo(maximum) >= 0) {
            throw invalid("trip_price_invalid");
        }
    }

    private void validateSchedule(TripCreateDTO trip, Instant now) {
        LocalDate today = now.atZone(TripPolicy.TIME_ZONE).toLocalDate();
        // A valid client request can cross midnight while routing or waiting for a lock.
        if (trip.getFirstDepartureDate().isBefore(today)) {
            throw invalid("trip_departure_in_past");
        }
        if (trip.getFirstDepartureDate().isAfter(today.plusDays(TripPolicy.MAX_DEPARTURE_DAYS_AHEAD))) {
            throw invalid("trip_departure_date_invalid");
        }
        LocalDateTime departure = LocalDateTime.of(trip.getFirstDepartureDate(), trip.getDepartureLocalTime());
        if (departure.getSecond() != 0 || departure.getNano() != 0
                || TripPolicy.TIME_ZONE.getRules().getValidOffsets(departure).isEmpty()) {
            throw invalid("trip_departure_time_invalid");
        }
        // Use the second occurrence in the autumn overlap, consistent with PostgreSQL AT TIME ZONE.
        if (!departure.atZone(TripPolicy.TIME_ZONE).withLaterOffsetAtOverlap().toInstant().isAfter(now)) {
            throw invalid("trip_departure_in_past");
        }
        List<Boolean> days = List.of(trip.isMonday(), trip.isTuesday(), trip.isWednesday(),
                trip.isThursday(), trip.isFriday(), trip.isSaturday(), trip.isSunday());
        if (trip.getScheduleType() == TripScheduleType.ONE_TIME) {
            if (days.contains(true)) {
                throw invalid("trip_one_time_days_invalid");
            }
        } else if (!days.contains(true)
                || !days.get(trip.getFirstDepartureDate().getDayOfWeek().getValue() - 1)) {
            throw invalid("trip_recurring_days_invalid");
        }
    }

    private TripPublicationException invalid(String code) {
        return new TripPublicationException(code, HttpStatus.BAD_REQUEST);
    }
}
