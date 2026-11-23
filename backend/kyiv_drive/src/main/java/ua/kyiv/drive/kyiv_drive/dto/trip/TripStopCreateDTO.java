package ua.kyiv.drive.kyiv_drive.dto.trip;

import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.UUID;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class TripStopCreateDTO {
    @NotNull(message = "Stop ID is required")
    private UUID stopId;
    @NotNull(message = "Enabled state is required")
    private Boolean isEnabled = true;
}
