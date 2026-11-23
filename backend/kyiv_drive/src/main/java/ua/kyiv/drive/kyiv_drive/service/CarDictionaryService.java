package ua.kyiv.drive.kyiv_drive.service;

import lombok.RequiredArgsConstructor;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;
import ua.kyiv.drive.kyiv_drive.dto.car.CarBrandDTO;
import ua.kyiv.drive.kyiv_drive.dto.car.CarModelResponseDTO;
import ua.kyiv.drive.kyiv_drive.mapper.CarMapper;
import ua.kyiv.drive.kyiv_drive.repository.CarBrandRepository;
import ua.kyiv.drive.kyiv_drive.repository.CarModelRepository;

import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class CarDictionaryService {

    private final CarBrandRepository brandRepository;
    private final CarModelRepository modelRepository;
    private final CarMapper carMapper;

    @Cacheable(value = "car_brands", key = "'all'")
    public List<CarBrandDTO> getAllBrands() {
        return brandRepository.findAllByOrderByNameAsc().stream()
                .map(carMapper::toBrandDTO)
                .collect(Collectors.toList());
    }

    @Cacheable(value = "car_models", key = "#brandId")
    public List<CarModelResponseDTO> getModelsByBrand(UUID brandId) {
        return modelRepository.findByBrandIdAndIsVerifiedTrueOrderByNameAsc(brandId).stream()
                .map(carMapper::toModelResponseDTO)
                .collect(Collectors.toList());
    }
}