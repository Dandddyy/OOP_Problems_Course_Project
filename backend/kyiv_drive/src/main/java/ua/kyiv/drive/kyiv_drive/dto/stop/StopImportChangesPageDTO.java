package ua.kyiv.drive.kyiv_drive.dto.stop;

import java.util.List;
import java.util.UUID;

public record StopImportChangesPageDTO(
        UUID importId,
        Long catalogVersion,
        boolean changesRecorded,
        List<StopImportChangeDTO> changes,
        int page,
        int size,
        long totalElements,
        int totalPages
) {
}
