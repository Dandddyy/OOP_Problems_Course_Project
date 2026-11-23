package ua.kyiv.drive.kyiv_drive.dto.stop;

import java.time.Instant;
import java.util.UUID;

public record StopCatalogVersionDTO(
        long catalogVersion,
        UUID importId,
        Instant appliedAt
) {
}
