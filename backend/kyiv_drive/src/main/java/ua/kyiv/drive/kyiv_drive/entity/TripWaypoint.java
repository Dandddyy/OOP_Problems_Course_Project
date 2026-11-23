package ua.kyiv.drive.kyiv_drive.entity;

import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.io.Serial;
import java.io.Serializable;

@Getter
@Setter
@EqualsAndHashCode
@NoArgsConstructor
@AllArgsConstructor
public class TripWaypoint implements Serializable {

    @Serial
    private static final long serialVersionUID = -3167131710455183477L;

    @NotNull(message = "Waypoint latitude is required")
    private Double lat;

    @NotNull(message = "Waypoint longitude is required")
    private Double lon;
}
