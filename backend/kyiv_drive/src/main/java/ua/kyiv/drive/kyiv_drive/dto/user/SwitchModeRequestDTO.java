package ua.kyiv.drive.kyiv_drive.dto.user;

import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import ua.kyiv.drive.kyiv_drive.entity.CurrentMode;

@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
public class SwitchModeRequestDTO {
    @NotNull(message = "Target mode is required")
    private CurrentMode targetMode;
}
