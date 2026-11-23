package ua.kyiv.drive.kyiv_drive.dto.car;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import ua.kyiv.drive.kyiv_drive.entity.CarColor;

import java.util.UUID;

@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
public class CarResponseDTO {
    private UUID id;
    private UUID brandId;
    private String brandName;
    private UUID modelId;
    private String modelName;
    private CarColor color;
    private String plateNumber;
    private Short passengerCapacity;
}
