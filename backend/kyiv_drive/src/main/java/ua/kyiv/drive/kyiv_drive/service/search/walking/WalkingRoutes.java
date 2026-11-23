package ua.kyiv.drive.kyiv_drive.service.search.walking;

import ua.kyiv.drive.kyiv_drive.model.search.SearchCoordinate;
import ua.kyiv.drive.kyiv_drive.model.search.WalkingMetric;

import java.util.Map;

public record WalkingRoutes(String graphRevision, Map<SearchCoordinate, WalkingMetric> toPickups,
                            Map<SearchCoordinate, WalkingMetric> fromDropoffs) {
    public WalkingRoutes {
        toPickups = Map.copyOf(toPickups);
        fromDropoffs = Map.copyOf(fromDropoffs);
    }
}
