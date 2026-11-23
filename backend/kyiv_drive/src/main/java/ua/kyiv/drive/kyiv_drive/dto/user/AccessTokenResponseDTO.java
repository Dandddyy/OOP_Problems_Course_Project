package ua.kyiv.drive.kyiv_drive.dto.user;

import java.time.Instant;

public record AccessTokenResponseDTO(
        String tokenType,
        String accessToken,
        Instant accessTokenExpiresAt,
        SessionContextDTO session
) {
}
