package ua.kyiv.drive.kyiv_drive.service;

import lombok.RequiredArgsConstructor;
import org.hibernate.exception.ConstraintViolationException;
import org.springframework.context.MessageSource;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import ua.kyiv.drive.kyiv_drive.dto.car.*;
import ua.kyiv.drive.kyiv_drive.entity.*;
import ua.kyiv.drive.kyiv_drive.exception.AccessDeniedException;
import ua.kyiv.drive.kyiv_drive.exception.FieldValidationException;
import ua.kyiv.drive.kyiv_drive.exception.ResourceNotFoundException;
import ua.kyiv.drive.kyiv_drive.mapper.CarMapper;
import ua.kyiv.drive.kyiv_drive.repository.*;

import java.util.List;
import java.util.Objects;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CarService {

    private static final String ACTIVE_PLATE_UNIQUE_INDEX = "idx_unique_plate_per_user";

    private final CarRepository carRepository;
    private final TripRepository tripRepository;
    private final UserRepository userRepository;
    private final CarBrandRepository brandRepository;
    private final CarModelRepository modelRepository;
    private final CarMapper carMapper;
    private final MessageSource messageSource;

    private final CarDictionaryService dictionaryService;

    public CarInitDataDTO getInitData(UUID userId) {
        List<CarBrandDTO> brands = dictionaryService.getAllBrands();

        List<CarResponseDTO> myCars = carRepository.findActiveCarsByOwnerIdWithDetails(userId).stream()
                .map(carMapper::toResponseDTO)
                .collect(Collectors.toList());

        return new CarInitDataDTO(brands, myCars);
    }

    public List<CarModelResponseDTO> getModelsByBrand(UUID brandId) {
        return dictionaryService.getModelsByBrand(brandId);
    }

    @Transactional
    public CarResponseDTO addCar(CarRequestDTO request, UUID userId) {
        userRepository.findByIdForUpdate(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));
        long activeCarsCount = carRepository.countByOwnerIdAndIsDeletedFalse(userId);
        if (activeCarsCount >= 3) {
            throw new IllegalStateException("You can only have up to 3 active cars.");
        }

        String cleanPlate = request.getPlateNumber();

        if (carRepository.findByOwnerIdAndPlateNumberAndIsDeletedFalse(userId, cleanPlate).isPresent()) {
            throw plateAlreadyExists();
        }

        CarModel model = resolveModel(request);
        Car car = new Car();
        car.setOwnerId(userId);
        applyCarDetails(car, request, model);
        return carMapper.toResponseDTO(saveCar(car));
    }

    @Transactional
    public CarResponseDTO updateCar(UUID carId, CarRequestDTO request, UUID userId) {
        Car car = requireOwnedCarForUpdate(carId, userId);
        if (car.isDeleted()) {
            throw new ResourceNotFoundException("Car not found");
        }

        if (matchesCarDetails(car, request)) {
            return carMapper.toResponseDTO(car);
        }

        if (carRepository.findByOwnerIdAndPlateNumberAndIsDeletedFalse(userId, request.getPlateNumber())
                .filter(existing -> !existing.getId().equals(carId)).isPresent()) {
            throw plateAlreadyExists();
        }

        CarModel model = resolveModel(request);
        if (tripRepository.existsByCarId(carId)) {
            car.setDeleted(true);
            // Release the active plate before Hibernate inserts its replacement.
            carRepository.flush();
            car = new Car();
            car.setOwnerId(userId);
        }

        applyCarDetails(car, request, model);
        return carMapper.toResponseDTO(saveCar(car));
    }

    private boolean matchesCarDetails(Car car, CarRequestDTO request) {
        return car.getModel().getBrand().getId().equals(request.getBrandId())
                && car.getModel().getName().strip().equalsIgnoreCase(request.getModelName())
                && car.getColor() == request.getColor()
                && car.getPlateNumber().equals(request.getPlateNumber())
                && Objects.equals(car.getPassengerCapacity(), request.getPassengerCapacity());
    }

    private CarModel resolveModel(CarRequestDTO request) {
        CarBrand brand = brandRepository.findById(request.getBrandId())
                .orElseThrow(() -> new IllegalArgumentException("Brand not found"));

        return modelRepository.findByBrandIdAndNameIgnoreCase(request.getBrandId(), request.getModelName())
                .orElseGet(() -> {
                    CarModel newModel = new CarModel();
                    newModel.setBrand(brand);
                    newModel.setName(request.getModelName());
                    newModel.setVerified(false);
                    return modelRepository.save(newModel);
                });
    }

    private void applyCarDetails(Car car, CarRequestDTO request, CarModel model) {
        car.setModel(model);
        car.setColor(request.getColor());
        car.setPlateNumber(request.getPlateNumber());
        car.setPassengerCapacity(request.getPassengerCapacity());
    }

    private Car saveCar(Car car) {
        try {
            return carRepository.saveAndFlush(car);
        } catch (DataIntegrityViolationException exception) {
            if (isActivePlateUniqueConstraintViolation(exception)) {
                throw plateAlreadyExists();
            }
            throw exception;
        }
    }

    private boolean isActivePlateUniqueConstraintViolation(Throwable exception) {
        Throwable current = exception;
        while (current != null) {
            if (current instanceof ConstraintViolationException constraintViolation
                    && ACTIVE_PLATE_UNIQUE_INDEX.equalsIgnoreCase(constraintViolation.getConstraintName())) {
                return true;
            }
            current = current.getCause();
        }
        return false;
    }

    private FieldValidationException plateAlreadyExists() {
        return new FieldValidationException(
                "plateNumber",
                messageSource.getMessage(
                        "error.car_plate_exists",
                        null,
                        LocaleContextHolder.getLocale()
                )
        );
    }

    @Transactional
    public void deleteCar(UUID carId, UUID userId) {
        Car car = requireOwnedCarForUpdate(carId, userId);

        if (tripRepository.existsByCarId(carId)) {
            car.setDeleted(true);
            carRepository.save(car);
        } else {
            carRepository.delete(car);
        }
    }

    private Car requireOwnedCarForUpdate(UUID carId, UUID userId) {
        Car car = carRepository.findByIdForUpdate(carId)
                .orElseThrow(() -> new ResourceNotFoundException("Car not found"));
        if (!car.getOwnerId().equals(userId)) {
            throw new AccessDeniedException("Access denied");
        }
        return car;
    }
}
