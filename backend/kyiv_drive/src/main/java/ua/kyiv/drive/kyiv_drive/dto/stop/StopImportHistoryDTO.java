package ua.kyiv.drive.kyiv_drive.dto.stop;

import ua.kyiv.drive.kyiv_drive.entity.StopImportStatus;

import java.time.Instant;
import java.util.UUID;

public record StopImportHistoryDTO(
        UUID importId,
        Long catalogVersion,
        boolean changesRecorded,
        StopImportStatus status,
        String originalFilename,
        String fileHash,
        String catalogHash,
        int totalFeatures,
        int acceptedStops,
        int outOfBoundsFeatures,
        int currentActiveStops,
        int newStops,
        int existingStops,
        int changedStops,
        int unchangedStops,
        int renamedStops,
        int movedStops,
        int reactivatedStops,
        int deactivatedStops,
        double deactivationPercentage,
        boolean confirmationRequired,
        boolean confirmationProvided,
        UUID previewedByUserId,
        String previewedByEmail,
        Instant previewedAt,
        UUID appliedByUserId,
        String appliedByEmail,
        Instant appliedAt
) {
}
