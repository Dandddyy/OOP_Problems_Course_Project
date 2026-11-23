package ua.kyiv.drive.kyiv_drive.mapper;

import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import ua.kyiv.drive.kyiv_drive.dto.template.TemplateCreateDTO;
import ua.kyiv.drive.kyiv_drive.dto.template.TemplateResponseDTO;
import ua.kyiv.drive.kyiv_drive.entity.Template;

@Mapper(componentModel = "spring")
public interface TemplateMapper {
    @Mapping(target = "startLat", expression = "java(template.getStartLocation() != null ? template.getStartLocation().getY() : null)")
    @Mapping(target = "startLon", expression = "java(template.getStartLocation() != null ? template.getStartLocation().getX() : null)")
    @Mapping(target = "endLat", expression = "java(template.getEndLocation() != null ? template.getEndLocation().getY() : null)")
    @Mapping(target = "endLon", expression = "java(template.getEndLocation() != null ? template.getEndLocation().getX() : null)")
    TemplateResponseDTO toDTO(Template template);

    default Point toPoint(Double lon, Double lat) {
        if (lon == null || lat == null) return null;
        GeometryFactory geometryFactory = new GeometryFactory(new PrecisionModel(), 4326);
        return geometryFactory.createPoint(new Coordinate(lon, lat));
    }

    @Mapping(target = "startLocation", expression = "java(toPoint(dto.getStartLon(), dto.getStartLat()))")
    @Mapping(target = "endLocation", expression = "java(toPoint(dto.getEndLon(), dto.getEndLat()))")
    @Mapping(target = "id", ignore = true)
    @Mapping(target = "userId", ignore = true)
    @Mapping(target = "requestId", ignore = true)
    @Mapping(target = "templateStops", ignore = true)
    @Mapping(target = "createdAt", ignore = true)
    @Mapping(target = "stopsCatalogVersion", ignore = true)
    @Mapping(target = "isDriver", ignore = true)
    @Mapping(target = "routePolyline", ignore = true)
    @Mapping(target = "totalDurationSeconds", ignore = true)
    @Mapping(target = "totalDistanceMeters", ignore = true)
    Template toEntity(TemplateCreateDTO dto);
}
