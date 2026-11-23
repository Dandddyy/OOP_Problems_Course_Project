package ua.kyiv.drive.kyiv_drive.auth;

import java.time.Instant;
import java.util.UUID;

public record RefreshTokenClaims(
        UUID userId,
        UUID sessionId,
        long generation,
        Instant expiresAt
) {
}
