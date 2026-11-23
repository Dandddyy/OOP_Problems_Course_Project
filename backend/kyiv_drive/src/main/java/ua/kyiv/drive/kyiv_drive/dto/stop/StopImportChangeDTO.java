package ua.kyiv.drive.kyiv_drive.dto.stop;

import ua.kyiv.drive.kyiv_drive.entity.StopImportChangeType;

import java.time.Instant;
import java.util.UUID;

public record StopImportChangeDTO(
        UUID id,
        UUID stopId,
        long osmId,
        StopImportChangeType changeType,
        StopImportChangeSnapshotDTO before,
        StopImportChangeSnapshotDTO after,
        Instant createdAt
) {
}
