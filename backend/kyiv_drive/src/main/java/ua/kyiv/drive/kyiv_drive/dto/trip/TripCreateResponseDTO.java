package ua.kyiv.drive.kyiv_drive.dto.trip;

import java.time.Instant;
import java.util.UUID;

public record TripCreateResponseDTO(
        UUID tripId,
        boolean created,
        Instant confirmationExpiresAt,
        String message
) {
}
