package ua.kyiv.drive.kyiv_drive.dto.trip;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import ua.kyiv.drive.kyiv_drive.validation.RoutePolicy;

import java.util.List;
import java.util.UUID;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class CreateTripWrapperDTO {
    @NotNull(message = "Request ID is required")
    private UUID requestId;
    @NotNull(message = "Trip data is missing")
    @Valid
    private TripCreateDTO trip;
    @Size(max = RoutePolicy.MAX_STOPS, message = "Route stops exceed the maximum allowed count")
    private List<@NotNull(message = "Route stop cannot be null") @Valid TripStopCreateDTO> stops;
}
