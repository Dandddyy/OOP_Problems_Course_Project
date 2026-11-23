package ua.kyiv.drive.kyiv_drive.service.stop;

import ua.kyiv.drive.kyiv_drive.dto.stop.StopImportSummaryDTO;
import ua.kyiv.drive.kyiv_drive.entity.Stop;

import java.util.List;
import java.util.Map;

record StopImportPlan(
        StopImportSummaryDTO summary,
        Map<Long, Stop> existingStops,
        List<StopImportChangeDraft> changes
) {
    StopImportPlan {
        existingStops = Map.copyOf(existingStops);
        changes = List.copyOf(changes);
    }
}
