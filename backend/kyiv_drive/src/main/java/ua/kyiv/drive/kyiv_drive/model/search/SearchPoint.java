package ua.kyiv.drive.kyiv_drive.model.search;

import java.util.UUID;

public record SearchPoint(UUID stopId, int sequenceNumber, String name, SearchCoordinate coordinate,
                          int cumulativeDurationSeconds, int cumulativeDistanceMeters) {
}
