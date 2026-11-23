package ua.kyiv.drive.kyiv_drive.dto.stop;

import java.util.UUID;

public record StopImportSummaryDTO(
        UUID importId,
        Long catalogVersion,
        String status,
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
        boolean confirmationRequired
) {
    public StopImportSummaryDTO withStatus(String newStatus) {
        return new StopImportSummaryDTO(
                importId,
                catalogVersion,
                newStatus,
                fileHash,
                catalogHash,
                totalFeatures,
                acceptedStops,
                outOfBoundsFeatures,
                currentActiveStops,
                newStops,
                existingStops,
                changedStops,
                unchangedStops,
                renamedStops,
                movedStops,
                reactivatedStops,
                deactivatedStops,
                deactivationPercentage,
                confirmationRequired
        );
    }

    public StopImportSummaryDTO withImportId(UUID newImportId) {
        return new StopImportSummaryDTO(
                newImportId,
                catalogVersion,
                status,
                fileHash,
                catalogHash,
                totalFeatures,
                acceptedStops,
                outOfBoundsFeatures,
                currentActiveStops,
                newStops,
                existingStops,
                changedStops,
                unchangedStops,
                renamedStops,
                movedStops,
                reactivatedStops,
                deactivatedStops,
                deactivationPercentage,
                confirmationRequired
        );
    }

    public StopImportSummaryDTO withCatalogVersion(long newCatalogVersion) {
        return new StopImportSummaryDTO(
                importId,
                newCatalogVersion,
                status,
                fileHash,
                catalogHash,
                totalFeatures,
                acceptedStops,
                outOfBoundsFeatures,
                currentActiveStops,
                newStops,
                existingStops,
                changedStops,
                unchangedStops,
                renamedStops,
                movedStops,
                reactivatedStops,
                deactivatedStops,
                deactivationPercentage,
                confirmationRequired
        );
    }
}
