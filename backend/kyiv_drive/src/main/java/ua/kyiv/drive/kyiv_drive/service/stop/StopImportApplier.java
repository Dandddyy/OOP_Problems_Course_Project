package ua.kyiv.drive.kyiv_drive.service.stop;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import ua.kyiv.drive.kyiv_drive.config.OperationDeadline;
import ua.kyiv.drive.kyiv_drive.dto.stop.StopImportSummaryDTO;
import ua.kyiv.drive.kyiv_drive.entity.Stop;
import ua.kyiv.drive.kyiv_drive.entity.StopImport;
import ua.kyiv.drive.kyiv_drive.exception.FileValidationException;
import ua.kyiv.drive.kyiv_drive.repository.StopRepository;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class StopImportApplier {

    private final StopRepository stopRepository;
    private final StopImportPlanner importPlanner;
    private final StopImportSafetyValidator safetyValidator;
    private final StopImportHistoryService historyService;
    private final StopImportChangeService changeService;
    private final GeometryFactory geometryFactory = new GeometryFactory(new PrecisionModel(), 4326);

    @Transactional
    public StopImportSummaryDTO apply(
            StopImportDataset dataset,
            UUID importId,
            String expectedFileHash,
            String expectedCatalogHash,
            boolean confirmLargeDeactivation,
            UUID userId,
            String userEmail
    ) {
        validateHash("file", dataset.fileHash(), expectedFileHash);

        StopImport history = historyService.lockPreviewForApply(importId);
        validateHash("preview file", history.getFileHash(), expectedFileHash);
        validateHash("preview catalog", history.getCatalogHash(), expectedCatalogHash);

        StopImportPlan plan = importPlanner.planForApply(dataset);
        validateHash("catalog", plan.summary().catalogHash(), expectedCatalogHash);
        safetyValidator.validateConfirmation(plan.summary(), confirmLargeDeactivation);

        Set<Long> importedOsmIds = dataset.osmIds();
        List<Stop> stopsToSave = new ArrayList<>(dataset.stops().size());

        for (ParsedStop parsed : dataset.stops()) {
            OperationDeadline.check();
            Point location = geometryFactory.createPoint(new Coordinate(parsed.lon(), parsed.lat()));
            Stop stop = plan.existingStops().getOrDefault(parsed.osmId(), new Stop());
            stop.setOsmId(parsed.osmId());
            stop.setName(parsed.name());
            stop.setLocation(location);
            stop.setIsActive(true);
            stopsToSave.add(stop);
        }

        OperationDeadline.check();
        stopRepository.saveAll(stopsToSave);
        OperationDeadline.check();
        stopRepository.deactivateMissingStops(importedOsmIds);
        OperationDeadline.check();
        long catalogVersion = historyService.markApplied(
                history,
                confirmLargeDeactivation,
                userId,
                userEmail
        );
        Map<Long, Stop> affectedStops = new HashMap<>(plan.existingStops());
        stopsToSave.forEach(stop -> affectedStops.put(stop.getOsmId(), stop));
        changeService.recordChanges(history, plan.changes(), affectedStops);
        OperationDeadline.check();
        stopRepository.flush();
        OperationDeadline.check();

        log.info(
                "Successfully imported/updated {} stops from {} features; ignored {} out-of-bounds features",
                stopsToSave.size(),
                dataset.totalFeatureCount(),
                dataset.outOfBoundsFeatureCount()
        );

        return plan.summary()
                .withStatus("APPLIED")
                .withImportId(importId)
                .withCatalogVersion(catalogVersion);
    }

    private void validateHash(String type, String actualHash, String expectedHash) {
        if (expectedHash == null) {
            throw new FileValidationException("Expected " + type + " hash is required. Run preview again.");
        }

        byte[] actual = actualHash.getBytes(StandardCharsets.US_ASCII);
        byte[] expected = expectedHash.trim().toLowerCase(Locale.ROOT).getBytes(StandardCharsets.US_ASCII);
        if (!MessageDigest.isEqual(actual, expected)) {
            throw new FileValidationException(
                    "The " + type + " has changed since preview. Run preview again."
            );
        }
    }
}
