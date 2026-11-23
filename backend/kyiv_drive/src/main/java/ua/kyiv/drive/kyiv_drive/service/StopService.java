package ua.kyiv.drive.kyiv_drive.service;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import ua.kyiv.drive.kyiv_drive.dto.stop.StopCatalogVersionDTO;
import ua.kyiv.drive.kyiv_drive.dto.stop.StopImportChangesPageDTO;
import ua.kyiv.drive.kyiv_drive.dto.stop.StopImportHistoryDTO;
import ua.kyiv.drive.kyiv_drive.dto.stop.StopImportSummaryDTO;
import ua.kyiv.drive.kyiv_drive.repository.UserRepository;
import ua.kyiv.drive.kyiv_drive.service.stop.StopGeoJsonParser;
import ua.kyiv.drive.kyiv_drive.service.stop.StopImportApplier;
import ua.kyiv.drive.kyiv_drive.service.stop.StopImportChangeService;
import ua.kyiv.drive.kyiv_drive.service.stop.StopImportDataset;
import ua.kyiv.drive.kyiv_drive.service.stop.StopImportHistoryService;
import ua.kyiv.drive.kyiv_drive.service.stop.StopImportPlanner;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class StopService {

    private final StopGeoJsonParser stopGeoJsonParser;
    private final StopImportPlanner stopImportPlanner;
    private final StopImportApplier stopImportApplier;
    private final StopImportHistoryService stopImportHistoryService;
    private final StopImportChangeService stopImportChangeService;
    private final UserRepository userRepository;

    public StopImportSummaryDTO previewStopsImport(MultipartFile file, UUID userId) {
        StopImportDataset dataset = stopGeoJsonParser.parse(file);
        StopImportSummaryDTO summary = stopImportPlanner.preview(dataset);
        return stopImportHistoryService.recordPreview(
                summary,
                file.getOriginalFilename(),
                userId,
                userEmail(userId)
        );
    }

    public StopImportSummaryDTO applyStopsImport(
            MultipartFile file,
            UUID importId,
            String expectedFileHash,
            String expectedCatalogHash,
            boolean confirmLargeDeactivation,
            UUID userId
    ) {
        StopImportDataset dataset = stopGeoJsonParser.parse(file);
        return stopImportApplier.apply(
                dataset,
                importId,
                expectedFileHash,
                expectedCatalogHash,
                confirmLargeDeactivation,
                userId,
                userEmail(userId)
        );
    }

    private String userEmail(UUID userId) {
        return userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found"))
                .getEmail();
    }

    public List<StopImportHistoryDTO> getImportHistory(int limit) {
        return stopImportHistoryService.getHistory(limit);
    }

    public StopCatalogVersionDTO getCurrentCatalogVersion() {
        return stopImportHistoryService.getCurrentCatalogVersion();
    }

    public StopImportChangesPageDTO getImportChanges(UUID importId, int page, int size) {
        return stopImportChangeService.getChanges(importId, page, size);
    }
}
