package ua.kyiv.drive.kyiv_drive.service.stop;

import lombok.RequiredArgsConstructor;
import org.locationtech.jts.geom.Point;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
import ua.kyiv.drive.kyiv_drive.config.OperationDeadline;
import ua.kyiv.drive.kyiv_drive.config.StopImportProperties;
import ua.kyiv.drive.kyiv_drive.dto.stop.StopImportSummaryDTO;
import ua.kyiv.drive.kyiv_drive.entity.Stop;
import ua.kyiv.drive.kyiv_drive.entity.StopImportChangeType;
import ua.kyiv.drive.kyiv_drive.repository.StopRepository;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;

@Component
@RequiredArgsConstructor
public class StopImportPlanner {

    private final StopRepository stopRepository;
    private final StopImportProperties properties;
    private final StopCatalogHasher catalogHasher;

    @Transactional(readOnly = true)
    public StopImportSummaryDTO preview(StopImportDataset dataset) {
        return buildPlan(dataset, stopRepository.findAll()).summary();
    }

    StopImportPlan planForApply(StopImportDataset dataset) {
        return buildPlan(dataset, stopRepository.findAllForUpdate());
    }

    private StopImportPlan buildPlan(StopImportDataset dataset, List<Stop> allStops) {
        Map<Long, Stop> existingStops = allStops.stream()
                .collect(Collectors.toMap(Stop::getOsmId, Function.identity()));
        Set<Long> importedOsmIds = dataset.osmIds();
        List<StopImportChangeDraft> changes = new ArrayList<>();

        int currentActiveStops = 0;
        int deactivatedStops = 0;
        for (Stop stop : allStops) {
            OperationDeadline.check();
            if (Boolean.TRUE.equals(stop.getIsActive())) {
                currentActiveStops++;
                if (!importedOsmIds.contains(stop.getOsmId())) {
                    deactivatedStops++;
                    StopImportChangeSnapshot before = StopImportChangeSnapshot.fromStop(stop);
                    changes.add(new StopImportChangeDraft(
                            stop.getId(),
                            stop.getOsmId(),
                            StopImportChangeType.DEACTIVATED,
                            before,
                            before.withActive(false)
                    ));
                }
            }
        }

        int newStops = 0;
        int existingStopCount = 0;
        int changedStops = 0;
        int unchangedStops = 0;
        int renamedStops = 0;
        int movedStops = 0;
        int reactivatedStops = 0;

        for (ParsedStop parsed : dataset.stops()) {
            OperationDeadline.check();
            Stop existing = existingStops.get(parsed.osmId());
            if (existing == null) {
                newStops++;
                changes.add(new StopImportChangeDraft(
                        null,
                        parsed.osmId(),
                        StopImportChangeType.ADDED,
                        null,
                        StopImportChangeSnapshot.fromParsedStop(parsed)
                ));
                continue;
            }

            existingStopCount++;
            boolean renamed = !Objects.equals(existing.getName(), parsed.name());
            boolean moved = hasMoved(existing.getLocation(), parsed);
            boolean reactivated = !Boolean.TRUE.equals(existing.getIsActive());
            StopImportChangeSnapshot before = StopImportChangeSnapshot.fromStop(existing);
            StopImportChangeSnapshot after = StopImportChangeSnapshot.fromParsedStop(parsed);

            if (renamed) {
                renamedStops++;
                changes.add(new StopImportChangeDraft(
                        existing.getId(),
                        parsed.osmId(),
                        StopImportChangeType.RENAMED,
                        before,
                        after
                ));
            }
            if (moved) {
                movedStops++;
                changes.add(new StopImportChangeDraft(
                        existing.getId(),
                        parsed.osmId(),
                        StopImportChangeType.MOVED,
                        before,
                        after
                ));
            }
            if (reactivated) {
                reactivatedStops++;
                changes.add(new StopImportChangeDraft(
                        existing.getId(),
                        parsed.osmId(),
                        StopImportChangeType.REACTIVATED,
                        before,
                        after
                ));
            }
            if (renamed || moved || reactivated) {
                changedStops++;
            } else {
                unchangedStops++;
            }
        }

        double deactivationPercentage = currentActiveStops == 0
                ? 0.0
                : (double) deactivatedStops * 100.0 / currentActiveStops;
        boolean confirmationRequired = currentActiveStops > 0
                && (double) deactivatedStops / currentActiveStops > properties.getMaximumDeactivationRatio();

        StopImportSummaryDTO summary = new StopImportSummaryDTO(
                null,
                null,
                "PREVIEWED",
                dataset.fileHash(),
                catalogHasher.hash(allStops),
                dataset.totalFeatureCount(),
                dataset.stops().size(),
                dataset.outOfBoundsFeatureCount(),
                currentActiveStops,
                newStops,
                existingStopCount,
                changedStops,
                unchangedStops,
                renamedStops,
                movedStops,
                reactivatedStops,
                deactivatedStops,
                deactivationPercentage,
                confirmationRequired
        );

        return new StopImportPlan(summary, existingStops, changes);
    }

    private boolean hasMoved(Point currentLocation, ParsedStop parsed) {
        return Double.compare(currentLocation.getX(), parsed.lon()) != 0
                || Double.compare(currentLocation.getY(), parsed.lat()) != 0;
    }
}
