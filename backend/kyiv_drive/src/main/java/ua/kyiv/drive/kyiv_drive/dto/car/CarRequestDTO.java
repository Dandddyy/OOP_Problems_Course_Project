package ua.kyiv.drive.kyiv_drive.dto.car;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import tools.jackson.databind.annotation.JsonDeserialize;
import ua.kyiv.drive.kyiv_drive.entity.CarColor;
import ua.kyiv.drive.kyiv_drive.validation.InputValidation;
import ua.kyiv.drive.kyiv_drive.validation.PassengerCapacityDeserializer;

import java.util.UUID;

@Getter
@Setter
@NoArgsConstructor
public class CarRequestDTO {

    @NotNull(message = "Brand ID is required")
    private UUID brandId;

    @NotBlank(message = "Model name cannot be empty")
    @Size(
            max = InputValidation.MAX_CAR_CATALOG_NAME_LENGTH,
            message = "Model name cannot exceed {max} characters"
    )
    @Pattern(
            regexp = InputValidation.CAR_MODEL_NAME,
            message = "Model name contains invalid characters"
    )
    private String modelName;

    @NotNull(message = "Color is required")
    private CarColor color;

    @NotBlank(message = "Plate number cannot be empty")
    @Pattern(
            regexp = InputValidation.CAR_PLATE_NUMBER,
            message = "Invalid plate number format. Standard plates must use Latin letters."
    )
    private String plateNumber;

    @NotNull(message = "Passenger capacity is required")
    @Min(value = 1, message = "Capacity must be at least 1")
    @Max(value = 90, message = "Capacity cannot exceed 90")
    @JsonDeserialize(using = PassengerCapacityDeserializer.class)
    private Short passengerCapacity;

    @JsonCreator
    public CarRequestDTO(
            @JsonProperty("brandId") UUID brandId,
            @JsonProperty("modelName") String modelName,
            @JsonProperty("color") CarColor color,
            @JsonProperty("plateNumber") String plateNumber,
            @JsonProperty("passengerCapacity") Short passengerCapacity
    ) {
        this.brandId = brandId;
        setModelName(modelName);
        this.color = color;
        this.plateNumber = plateNumber;
        this.passengerCapacity = passengerCapacity;
    }

    public void setModelName(String modelName) {
        this.modelName = (modelName != null) ? modelName.strip() : null;
    }

    public void setPlateNumber(String plateNumber) {
        if (plateNumber != null) {
            this.plateNumber = plateNumber.replaceAll("\\s+", "").toUpperCase();
        } else {
            this.plateNumber = null;
        }
    }
}
