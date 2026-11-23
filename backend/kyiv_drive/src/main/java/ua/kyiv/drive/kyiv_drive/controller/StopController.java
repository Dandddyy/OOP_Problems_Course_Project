package ua.kyiv.drive.kyiv_drive.controller;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.context.request.async.DeferredResult;
import org.springframework.web.multipart.MultipartFile;
import ua.kyiv.drive.kyiv_drive.auth.UserPrincipal;
import ua.kyiv.drive.kyiv_drive.dto.stop.StopCatalogVersionDTO;
import ua.kyiv.drive.kyiv_drive.dto.stop.StopImportChangesPageDTO;
import ua.kyiv.drive.kyiv_drive.dto.stop.StopImportHistoryDTO;
import ua.kyiv.drive.kyiv_drive.dto.stop.StopImportSummaryDTO;
import ua.kyiv.drive.kyiv_drive.service.StopService;
import ua.kyiv.drive.kyiv_drive.service.execution.OperationExecutor;
import ua.kyiv.drive.kyiv_drive.service.execution.OperationPlan;
import ua.kyiv.drive.kyiv_drive.service.execution.OperationProfile;
import ua.kyiv.drive.kyiv_drive.validation.StopImportPolicy;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/stop")
@RequiredArgsConstructor
public class StopController {

    private final StopService stopService;
    private final OperationExecutor executor;

    @PostMapping("/import/preview")
    public DeferredResult<StopImportSummaryDTO> previewImport(
            @RequestParam("file") MultipartFile file,
            @AuthenticationPrincipal UserPrincipal principal
    ) {
        return executor.execute(new OperationPlan<>(OperationProfile.STOP_IMPORT,
                () -> stopService.previewStopsImport(file, principal.getId())));
    }

    @PostMapping("/import/apply")
    public DeferredResult<StopImportSummaryDTO> applyImport(
            @RequestParam("file") MultipartFile file,
            @RequestParam("importId") UUID importId,
            @RequestParam("expectedFileHash") String expectedFileHash,
            @RequestParam("expectedCatalogHash") String expectedCatalogHash,
            @RequestParam(value = "confirmLargeDeactivation", defaultValue = "false")
            boolean confirmLargeDeactivation,
            @AuthenticationPrincipal UserPrincipal principal
    ) {
        return executor.execute(new OperationPlan<>(OperationProfile.STOP_IMPORT, () -> stopService.applyStopsImport(
                file, importId, expectedFileHash, expectedCatalogHash, confirmLargeDeactivation, principal.getId())));
    }

    @GetMapping("/import/history")
    public ResponseEntity<List<StopImportHistoryDTO>> getImportHistory(
            @RequestParam(value = "limit", defaultValue = "50")
            @Min(value = 1, message = "History limit must be positive")
            @Max(value = StopImportPolicy.MAX_HISTORY_LIMIT, message = "History limit cannot exceed {value}") int limit
    ) {
        return ResponseEntity.ok(stopService.getImportHistory(limit));
    }

    @GetMapping("/import/{importId}/changes")
    public ResponseEntity<StopImportChangesPageDTO> getImportChanges(
            @PathVariable UUID importId,
            @RequestParam(value = "page", defaultValue = "0")
            @Min(value = 0, message = "Page number cannot be negative") int page,
            @RequestParam(value = "size", defaultValue = "100")
            @Min(value = 1, message = "Page size must be positive")
            @Max(value = StopImportPolicy.MAX_CHANGE_PAGE_SIZE, message = "Page size cannot exceed {value}") int size
    ) {
        return ResponseEntity.ok(stopService.getImportChanges(importId, page, size));
    }

    @GetMapping("/catalog/version")
    public ResponseEntity<StopCatalogVersionDTO> getCurrentCatalogVersion() {
        return ResponseEntity.ok(stopService.getCurrentCatalogVersion());
    }
}
