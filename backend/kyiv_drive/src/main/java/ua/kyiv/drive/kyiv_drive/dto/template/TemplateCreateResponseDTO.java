package ua.kyiv.drive.kyiv_drive.dto.template;

import java.util.UUID;

public record TemplateCreateResponseDTO(
        UUID templateId,
        boolean created,
        String message
) {
}
