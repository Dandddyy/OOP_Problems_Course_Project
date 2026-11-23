package ua.kyiv.drive.kyiv_drive.service.stop;

public record ParsedStop(
        long osmId,
        String name,
        double lat,
        double lon
) {
}
