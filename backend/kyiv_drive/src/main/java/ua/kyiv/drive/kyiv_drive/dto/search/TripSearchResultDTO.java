package ua.kyiv.drive.kyiv_drive.dto.search;

import com.fasterxml.jackson.annotation.JsonInclude;
import ua.kyiv.drive.kyiv_drive.entity.TripPricingType;

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Set;
import java.util.UUID;

/**
 * All prices are in Ukrainian hryvnias (UAH).
 * Seat counts are temporary 1/1 placeholders until booking availability is implemented.
 *
 * @param availableSeats available passenger seats
 * @param totalSeats total offered passenger seats, excluding the driver's seat
 */
public record TripSearchResultDTO(UUID tripId, UUID driverId, String driverName,
                                  String driverAvatarUrl, BigDecimal driverRating, int driverRatingCount,
                                  UUID carId, String carLabel, int availableSeats, int totalSeats,
                                  PointDTO pickup, PointDTO dropoff, WalkingMetricDTO walkingToPickup,
                                  WalkingMetricDTO walkingFromDropoff, int rideDurationSeconds, int rideDistanceMeters,
                                  BigDecimal priceAmount, TripPricingType pricingType,
                                  BigDecimal publishedRate, boolean negotiationAllowed, double score,
                                  ScoreComponentsDTO components, Set<DayOfWeek> matchedWeekdays,
                                  int matchedDateCount, int requestedDateCount, List<OccurrenceDTO> occurrences,
                                  @JsonInclude(JsonInclude.Include.NON_NULL) PreferenceMatchDTO preferenceMatch) {
    public record CoordinateDTO(double longitude, double latitude) {
    }

    public record PointDTO(UUID stopId, int sequenceNumber, String name, CoordinateDTO coordinate,
                           int cumulativeDurationSeconds, int cumulativeDistanceMeters) {
    }

    public record WalkingMetricDTO(boolean reachable, double distanceMeters, double durationSeconds) {
    }

    public record ScoreComponentsDTO(double departure, double arrival, double walking, double weekdays, double price,
                                     double duration) {
    }

    public record OccurrenceDTO(LocalDate requestedDate, LocalDate driverDepartureDate, Instant leaveAt,
                                Instant boardAt, Instant alightAt, Instant arriveAt) {
    }

    public record PreferenceMatchDTO(boolean timeFits, ScheduleMatch schedule) {
    }

    public enum ScheduleMatch {
        FITS,
        INCOMPLETE,
        STARTS_LATER
    }
}
