package ua.kyiv.drive.kyiv_drive.mapper;

import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;
import ua.kyiv.drive.kyiv_drive.dto.trip.TripCreateDTO;
import ua.kyiv.drive.kyiv_drive.entity.Trip;

@Mapper(componentModel = "spring")
public interface TripMapper {
    default Point toPoint(Double lon, Double lat) {
        return new GeometryFactory(new PrecisionModel(), 4326).createPoint(new Coordinate(lon, lat));
    }

    @Mapping(target = "startLocation", expression = "java(toPoint(dto.getStartLon(), dto.getStartLat()))")
    @Mapping(target = "endLocation", expression = "java(toPoint(dto.getEndLon(), dto.getEndLat()))")
    @Mapping(target = "id", ignore = true)
    @Mapping(target = "driverId", ignore = true)
    @Mapping(target = "requestId", ignore = true)
    @Mapping(target = "routePolyline", ignore = true)
    @Mapping(target = "totalDistanceMeters", ignore = true)
    @Mapping(target = "totalDurationSeconds", ignore = true)
    @Mapping(target = "tripStatus", ignore = true)
    @Mapping(target = "recruitmentStatus", ignore = true)
    @Mapping(target = "lastConfirmedAt", ignore = true)
    @Mapping(target = "confirmationExpiresAt", ignore = true)
    @Mapping(target = "stopsCatalogVersion", ignore = true)
    @Mapping(target = "createdAt", ignore = true)
    @Mapping(target = "updatedAt", ignore = true)
    @Mapping(target = "tripStops", ignore = true)
    Trip toEntity(TripCreateDTO dto);
}
