package ua.kyiv.drive.kyiv_drive.dto.template;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import ua.kyiv.drive.kyiv_drive.entity.TripWaypoint;
import ua.kyiv.drive.kyiv_drive.validation.InputValidation;
import ua.kyiv.drive.kyiv_drive.validation.RoutePolicy;

import java.util.List;

@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
public class TemplateCreateDTO {

    private static final String POLYLINE_REGEX = "^[\\x3F-\\x7E]+$";

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
    @Pattern(regexp = POLYLINE_REGEX, message = "Invalid route polyline format")
    private String routePolyline;

    @NotNull(message = "Total duration is required")
    @PositiveOrZero(message = "Total duration cannot be negative")
    private Integer totalDurationSeconds;

    @NotNull(message = "Total distance is required")
    @Min(value = RoutePolicy.PASSENGER_MIN_DISTANCE_METERS, message = "Total distance is below the minimum route distance")
    @Max(value = RoutePolicy.MAX_DISTANCE_METERS, message = "Total distance exceeds the maximum route distance")
    private Integer totalDistanceMeters;

    public void setStartShortAddress(String startShortAddress) {
        this.startShortAddress = (startShortAddress != null) ? startShortAddress.strip() : null;
    }

    public void setStartSubtitle(String startSubtitle) {
        this.startSubtitle = (startSubtitle != null) ? startSubtitle.strip() : null;
    }

    public void setEndShortAddress(String endShortAddress) {
        this.endShortAddress = (endShortAddress != null) ? endShortAddress.strip() : null;
    }

    public void setEndSubtitle(String endSubtitle) {
        this.endSubtitle = (endSubtitle != null) ? endSubtitle.strip() : null;
    }
}
