package ua.kyiv.drive.kyiv_drive.dto.template;

import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.UUID;

@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
public class TemplateStopCreateDTO {

    @NotNull(message = "Stop ID is required")
    private UUID stopId;

    @NotNull(message = "Enabled state is required")
    private Boolean isEnabled = true;
}
