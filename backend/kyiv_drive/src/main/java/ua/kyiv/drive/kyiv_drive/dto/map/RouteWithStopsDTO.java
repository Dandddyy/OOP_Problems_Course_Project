package ua.kyiv.drive.kyiv_drive.dto.map;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.List;

@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
public class RouteWithStopsDTO {
    private RouteDTO route;
    private List<StopOnRouteDTO> stops;
}