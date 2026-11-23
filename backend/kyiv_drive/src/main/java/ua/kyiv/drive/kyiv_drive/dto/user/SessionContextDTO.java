package ua.kyiv.drive.kyiv_drive.dto.user;

import ua.kyiv.drive.kyiv_drive.entity.CurrentMode;

import java.util.UUID;

public record SessionContextDTO(UUID id, CurrentMode currentMode) {
}
