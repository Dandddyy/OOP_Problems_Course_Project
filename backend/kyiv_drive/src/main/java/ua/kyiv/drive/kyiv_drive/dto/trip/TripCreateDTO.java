package ua.kyiv.drive.kyiv_drive.dto.trip;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.Getter;
import lombok.Setter;
import ua.kyiv.drive.kyiv_drive.entity.TripPricingType;
import ua.kyiv.drive.kyiv_drive.entity.TripScheduleType;
import ua.kyiv.drive.kyiv_drive.entity.TripWaypoint;
import ua.kyiv.drive.kyiv_drive.validation.InputValidation;
import ua.kyiv.drive.kyiv_drive.validation.RoutePolicy;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.UUID;

@Getter
@Setter
public class TripCreateDTO {
    @NotNull(message = "Car ID is required")
    private UUID carId;

    @NotBlank(message = "Start address is required")
    @Size(max = InputValidation.MAX_ADDRESS_PART_LENGTH, message = "Start address exceeds maximum length")
    @Pattern(regexp = InputValidation.ADDRESS_PART, message = "Start address contains invalid characters")
    private String startShortAddress;

    @Size(max = InputValidation.MAX_ADDRESS_PART_LENGTH, message = "Start subtitle exceeds maximum length")
    @Pattern(regexp = InputValidation.OPTIONAL_ADDRESS_PART, message = "Start subtitle contains invalid characters")
    private String startSubtitle;

    @NotBlank(message = "End address is required")
    @Size(max = InputValidation.MAX_ADDRESS_PART_LENGTH, message = "End address exceeds maximum length")
    @Pattern(regexp = InputValidation.ADDRESS_PART, message = "End address contains invalid characters")
    private String endShortAddress;

    @Size(max = InputValidation.MAX_ADDRESS_PART_LENGTH, message = "End subtitle exceeds maximum length")
    @Pattern(regexp = InputValidation.OPTIONAL_ADDRESS_PART, message = "End subtitle contains invalid characters")
    private String endSubtitle;

    @NotNull(message = "Start latitude is required")
    private Double startLat;
    @NotNull(message = "Start longitude is required")
    private Double startLon;
    @NotNull(message = "End latitude is required")
    private Double endLat;
    @NotNull(message = "End longitude is required")
    private Double endLon;

    @Size(max = RoutePolicy.MAX_WAYPOINTS, message = "A route cannot contain more than {max} waypoints")
    private List<@NotNull(message = "Waypoint cannot be null") @Valid TripWaypoint> waypoints;

    @NotBlank(message = "Route polyline is required")
    @Size(max = RoutePolicy.MAX_POLYLINE_LENGTH, message = "Polyline size is too large")
    @Pattern(regexp = "^[\\x3F-\\x7E]+$", message = "Invalid route polyline format")
    private String routePolyline;

    @NotNull(message = "Total distance is required")
    @Min(value = RoutePolicy.MIN_DISTANCE_METERS, message = "Total distance is below the minimum route distance")
    @Max(value = RoutePolicy.MAX_DISTANCE_METERS, message = "Total distance exceeds the maximum route distance")
    private Integer totalDistanceMeters;

    @NotNull(message = "Total duration is required")
    @PositiveOrZero(message = "Total duration cannot be negative")
    private Integer totalDurationSeconds;

    @NotNull(message = "Schedule type is required")
    private TripScheduleType scheduleType;
    @NotNull(message = "First departure date is required")
    private LocalDate firstDepartureDate;
    @NotNull(message = "Departure time is required")
    private LocalTime departureLocalTime;

    private boolean monday;
    private boolean tuesday;
    private boolean wednesday;
    private boolean thursday;
    private boolean friday;
    private boolean saturday;
    private boolean sunday;

    @NotNull(message = "Pricing type is required")
    private TripPricingType pricingType;
    @NotNull(message = "Price is required")
    @DecimalMin(value = "0", inclusive = false, message = "Price must be positive")
    @Digits(integer = 3, fraction = 2, message = "Price must have at most {integer} integer digits and {fraction} decimal places")
    private BigDecimal priceAmount;

    @NotNull(message = "Negotiation state is required")
    private Boolean negotiationAllowed = true;

    @Size(max = 255, message = "Description cannot exceed {max} characters")
    private String description;

    public void setStartShortAddress(String value) {
        startShortAddress = strip(value);
    }

    public void setStartSubtitle(String value) {
        startSubtitle = strip(value);
    }

    public void setEndShortAddress(String value) {
        endShortAddress = strip(value);
    }

    public void setEndSubtitle(String value) {
        endSubtitle = strip(value);
    }

    public void setDescription(String value) {
        description = value == null || value.isBlank() ? null : value.strip();
    }

    private String strip(String value) {
        return value == null ? null : value.strip();
    }
}
