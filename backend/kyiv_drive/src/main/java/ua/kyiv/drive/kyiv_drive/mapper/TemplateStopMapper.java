package ua.kyiv.drive.kyiv_drive.mapper;

import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import ua.kyiv.drive.kyiv_drive.dto.template.TemplateStopResponseDTO;
import ua.kyiv.drive.kyiv_drive.entity.TemplateStop;

import java.util.List;

@Mapper(componentModel = "spring")
public interface TemplateStopMapper {
    @Mapping(target = "templateId", source = "template.id")
    @Mapping(target = "stopId", source = "stop.id")
    @Mapping(target = "isAvailable", source = "stop.isActive")
    @Mapping(target = "name", source = "stop.name")
    @Mapping(target = "lat", expression = "java(templateStop.getStop().getLocation().getY())")
    @Mapping(target = "lon", expression = "java(templateStop.getStop().getLocation().getX())")
    TemplateStopResponseDTO toDTO(TemplateStop templateStop);

    List<TemplateStopResponseDTO> toDTOList(List<TemplateStop> templateStops);
}
