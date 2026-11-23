package ua.kyiv.drive.kyiv_drive.dto.stop;

public record StopImportChangeSnapshotDTO(
        String name,
        Double lat,
        Double lon,
        Boolean active
) {
}
