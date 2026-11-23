package ua.kyiv.drive.kyiv_drive.service.stop;

import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;
import ua.kyiv.drive.kyiv_drive.config.OperationDeadline;
import ua.kyiv.drive.kyiv_drive.dto.stop.StopCatalogVersionDTO;
import ua.kyiv.drive.kyiv_drive.dto.stop.StopImportHistoryDTO;
import ua.kyiv.drive.kyiv_drive.dto.stop.StopImportSummaryDTO;
import ua.kyiv.drive.kyiv_drive.entity.StopImport;
import ua.kyiv.drive.kyiv_drive.entity.StopImportStatus;
import ua.kyiv.drive.kyiv_drive.exception.FileValidationException;
import ua.kyiv.drive.kyiv_drive.repository.StopImportRepository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class StopImportHistoryService {

    private final StopImportRepository stopImportRepository;

    @Transactional
    public StopImportSummaryDTO recordPreview(
            StopImportSummaryDTO summary,
            String originalFilename,
            UUID userId,
            String userEmail
    ) {
        StopImport stopImport = new StopImport();
        stopImport.setStatus(StopImportStatus.PREVIEWED);
        stopImport.setOriginalFilename(normalizeFilename(originalFilename));
        copySummary(summary, stopImport);
        stopImport.setPreviewedByUserId(userId);
        stopImport.setPreviewedByEmail(userEmail);

        OperationDeadline.check();
        StopImport saved = stopImportRepository.saveAndFlush(stopImport);
        OperationDeadline.check();
        return summary.withImportId(saved.getId());
    }

    StopImport lockPreviewForApply(UUID importId) {
        if (importId == null) {
            throw new FileValidationException("Import id is required. Run preview again.");
        }

        StopImport stopImport = stopImportRepository.findByIdForUpdate(importId)
                .orElseThrow(() -> new FileValidationException("Import preview was not found. Run preview again."));

        if (stopImport.getStatus() != StopImportStatus.PREVIEWED) {
            throw new FileValidationException("This import preview has already been applied.");
        }
        return stopImport;
    }

    long markApplied(
            StopImport stopImport,
            boolean confirmationProvided,
            UUID userId,
            String userEmail
    ) {
        long catalogVersion = stopImportRepository.nextCatalogVersion();
        stopImport.setStatus(StopImportStatus.APPLIED);
        stopImport.setCatalogVersion(catalogVersion);
        stopImport.setConfirmationProvided(confirmationProvided);
        stopImport.setAppliedByUserId(userId);
        stopImport.setAppliedByEmail(userEmail);
        stopImport.setAppliedAt(Instant.now());
        return catalogVersion;
    }

    @Transactional(readOnly = true)
    public List<StopImportHistoryDTO> getHistory(int limit) {
        return stopImportRepository.findAllByOrderByPreviewedAtDesc(PageRequest.of(0, limit)).stream()
                .map(this::toDTO)
                .toList();
    }

    @Transactional(readOnly = true)
    public StopCatalogVersionDTO getCurrentCatalogVersion() {
        return findCurrentCatalogImport()
                .map(stopImport -> new StopCatalogVersionDTO(
                        stopImport.getCatalogVersion(),
                        stopImport.getId(),
                        stopImport.getAppliedAt()
                ))
                .orElseGet(() -> new StopCatalogVersionDTO(0, null, null));
    }

    @Transactional(readOnly = true)
    public long getCurrentCatalogVersionNumber() {
        return findCurrentCatalogImport()
                .map(StopImport::getCatalogVersion)
                .orElse(0L);
    }

    private Optional<StopImport> findCurrentCatalogImport() {
        return stopImportRepository.findFirstByStatusAndCatalogVersionIsNotNullOrderByCatalogVersionDesc(
                StopImportStatus.APPLIED
        );
    }

    private void copySummary(StopImportSummaryDTO summary, StopImport stopImport) {
        stopImport.setFileHash(summary.fileHash());
        stopImport.setCatalogHash(summary.catalogHash());
        stopImport.setTotalFeatures(summary.totalFeatures());
        stopImport.setAcceptedStops(summary.acceptedStops());
        stopImport.setOutOfBoundsFeatures(summary.outOfBoundsFeatures());
        stopImport.setCurrentActiveStops(summary.currentActiveStops());
        stopImport.setNewStops(summary.newStops());
        stopImport.setExistingStops(summary.existingStops());
        stopImport.setChangedStops(summary.changedStops());
        stopImport.setUnchangedStops(summary.unchangedStops());
        stopImport.setRenamedStops(summary.renamedStops());
        stopImport.setMovedStops(summary.movedStops());
        stopImport.setReactivatedStops(summary.reactivatedStops());
        stopImport.setDeactivatedStops(summary.deactivatedStops());
        stopImport.setDeactivationPercentage(summary.deactivationPercentage());
        stopImport.setConfirmationRequired(summary.confirmationRequired());
    }

    private StopImportHistoryDTO toDTO(StopImport stopImport) {
        return new StopImportHistoryDTO(
                stopImport.getId(),
                stopImport.getCatalogVersion(),
                stopImport.isChangesRecorded(),
                stopImport.getStatus(),
                stopImport.getOriginalFilename(),
                stopImport.getFileHash(),
                stopImport.getCatalogHash(),
                stopImport.getTotalFeatures(),
                stopImport.getAcceptedStops(),
                stopImport.getOutOfBoundsFeatures(),
                stopImport.getCurrentActiveStops(),
                stopImport.getNewStops(),
                stopImport.getExistingStops(),
                stopImport.getChangedStops(),
                stopImport.getUnchangedStops(),
                stopImport.getRenamedStops(),
                stopImport.getMovedStops(),
                stopImport.getReactivatedStops(),
                stopImport.getDeactivatedStops(),
                stopImport.getDeactivationPercentage(),
                stopImport.isConfirmationRequired(),
                stopImport.isConfirmationProvided(),
                stopImport.getPreviewedByUserId(),
                stopImport.getPreviewedByEmail(),
                stopImport.getPreviewedAt(),
                stopImport.getAppliedByUserId(),
                stopImport.getAppliedByEmail(),
                stopImport.getAppliedAt()
        );
    }

    private String normalizeFilename(String filename) {
        if (!StringUtils.hasText(filename)) {
            return null;
        }

        String cleaned = StringUtils.cleanPath(filename.trim());
        int separatorIndex = Math.max(cleaned.lastIndexOf('/'), cleaned.lastIndexOf('\\'));
        String basename = separatorIndex >= 0 ? cleaned.substring(separatorIndex + 1) : cleaned;
        return basename.length() <= 255 ? basename : basename.substring(0, 255);
    }
}
