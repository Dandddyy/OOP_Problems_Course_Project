package ua.kyiv.drive.kyiv_drive.dto.map;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import java.util.UUID;

@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
public class StopOnRouteDTO {
    private UUID stopId;
    private String name;
    private Double lat;
    private Double lon;
    private Integer etaSeconds;
    private Integer distanceMeters;
}