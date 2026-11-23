package ua.kyiv.drive.kyiv_drive.service.stop;

import ua.kyiv.drive.kyiv_drive.entity.Stop;

record StopImportChangeSnapshot(
        String name,
        Double lat,
        Double lon,
        Boolean active
) {
    static StopImportChangeSnapshot fromStop(Stop stop) {
        return new StopImportChangeSnapshot(
                stop.getName(),
                stop.getLocation().getY(),
                stop.getLocation().getX(),
                stop.getIsActive()
        );
    }

    static StopImportChangeSnapshot fromParsedStop(ParsedStop stop) {
        return new StopImportChangeSnapshot(
                stop.name(),
                stop.lat(),
                stop.lon(),
                true
        );
    }

    StopImportChangeSnapshot withActive(boolean newActive) {
        return new StopImportChangeSnapshot(name, lat, lon, newActive);
    }
}
