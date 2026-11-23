package ua.kyiv.drive.kyiv_drive.dto.template;

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
@AllArgsConstructor
@NoArgsConstructor
public class CreateTemplateWrapperDTO {

    @NotNull(message = "Request ID is required")
    private UUID requestId;

    @Valid
    @NotNull(message = "Template data is missing")
    private TemplateCreateDTO template;

    @Size(max = RoutePolicy.MAX_STOPS, message = "Route stops exceed the maximum allowed count")
    private List<@NotNull(message = "Route stop cannot be null") @Valid TemplateStopCreateDTO> stops;
}
