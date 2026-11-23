package ua.kyiv.drive.kyiv_drive.service.stop;

import org.springframework.stereotype.Component;
import ua.kyiv.drive.kyiv_drive.dto.stop.StopImportSummaryDTO;
import ua.kyiv.drive.kyiv_drive.exception.FileValidationException;

@Component
public class StopImportSafetyValidator {

    public void validateConfirmation(StopImportSummaryDTO summary, boolean confirmed) {
        if (summary.confirmationRequired() && !confirmed) {
            throw new FileValidationException(
                    "Import would deactivate " + summary.deactivatedStops() + " of "
                            + summary.currentActiveStops() + " active stops and requires explicit confirmation."
            );
        }
    }
}
