package ua.kyiv.drive.kyiv_drive.mapper;

import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import ua.kyiv.drive.kyiv_drive.dto.car.CarBrandDTO;
import ua.kyiv.drive.kyiv_drive.dto.car.CarModelResponseDTO;
import ua.kyiv.drive.kyiv_drive.dto.car.CarResponseDTO;
import ua.kyiv.drive.kyiv_drive.entity.Car;
import ua.kyiv.drive.kyiv_drive.entity.CarBrand;
import ua.kyiv.drive.kyiv_drive.entity.CarModel;

@Mapper(componentModel = "spring")
public interface CarMapper {
    @Mapping(target = "brandId", source = "model.brand.id")
    @Mapping(target = "brandName", source = "model.brand.name")
    @Mapping(target = "modelId", source = "model.id")
    @Mapping(target = "modelName", source = "model.name")
    CarResponseDTO toResponseDTO(Car car);

    CarBrandDTO toBrandDTO(CarBrand brand);

    CarModelResponseDTO toModelResponseDTO(CarModel model);
}
