package ua.kyiv.drive.kyiv_drive.service.stop;

import ua.kyiv.drive.kyiv_drive.entity.StopImportChangeType;

import java.util.UUID;

record StopImportChangeDraft(
        UUID stopId,
        long osmId,
        StopImportChangeType changeType,
        StopImportChangeSnapshot before,
        StopImportChangeSnapshot after
) {
}
