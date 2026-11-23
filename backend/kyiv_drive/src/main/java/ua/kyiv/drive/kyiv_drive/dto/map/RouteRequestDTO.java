package ua.kyiv.drive.kyiv_drive.dto.map;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import ua.kyiv.drive.kyiv_drive.entity.TripWaypoint;
import ua.kyiv.drive.kyiv_drive.validation.RoutePolicy;

import java.util.List;

@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
public class RouteRequestDTO {

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
}
