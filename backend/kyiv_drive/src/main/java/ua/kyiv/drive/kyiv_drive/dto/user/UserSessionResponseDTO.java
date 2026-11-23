package ua.kyiv.drive.kyiv_drive.dto.user;

import ua.kyiv.drive.kyiv_drive.entity.CurrentMode;
import ua.kyiv.drive.kyiv_drive.entity.DevicePlatform;

import java.time.Instant;
import java.util.UUID;

public record UserSessionResponseDTO(
        UUID id,
        String deviceName,
        DevicePlatform platform,
        String appVersion,
        CurrentMode currentMode,
        Instant createdAt,
        Instant lastUsedAt,
        Instant idleExpiresAt,
        boolean current
) {
}
