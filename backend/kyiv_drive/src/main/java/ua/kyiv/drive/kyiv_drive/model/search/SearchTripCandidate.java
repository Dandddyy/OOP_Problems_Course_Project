package ua.kyiv.drive.kyiv_drive.model.search;

import ua.kyiv.drive.kyiv_drive.entity.TripPricingType;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record SearchTripCandidate(UUID tripId, UUID driverId, String driverName,
                                  String driverAvatarUrl, BigDecimal driverRating, int driverRatingCount,
                                  UUID carId, String carLabel,
                                  TripPricingType pricingType, BigDecimal priceAmount, boolean negotiationAllowed,
                                  Instant updatedAt, List<SearchPoint> pickups, List<SearchPoint> dropoffs,
                                  List<SearchOccurrence> occurrences) {
}
