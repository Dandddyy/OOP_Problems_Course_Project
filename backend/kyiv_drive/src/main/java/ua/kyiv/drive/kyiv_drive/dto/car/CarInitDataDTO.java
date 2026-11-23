package ua.kyiv.drive.kyiv_drive.dto.car;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.List;

@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
public class CarInitDataDTO {
    private List<CarBrandDTO> brands;
    private List<CarResponseDTO> myCars;
}
