package ua.kyiv.drive.kyiv_drive.dto.map;

import lombok.AllArgsConstructor;
import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@EqualsAndHashCode
@AllArgsConstructor
@NoArgsConstructor
public class RouteDTO {
    private String polyline;
    private int distanceMeters;
    private int durationSeconds;
}
