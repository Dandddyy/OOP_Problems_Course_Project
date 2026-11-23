package ua.kyiv.drive.kyiv_drive.dto.template;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.List;

@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
public class TemplateResponseWrapperDTO {
    private TemplateResponseDTO template;
    private List<TemplateStopResponseDTO> stops;
}
