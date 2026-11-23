package ua.kyiv.drive.kyiv_drive.dto.user;

import java.time.Instant;

public record PasswordResetTokenResponseDTO(
        String passwordResetToken,
        Instant expiresAt
) {
}
