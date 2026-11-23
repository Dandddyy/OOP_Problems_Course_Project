package ua.kyiv.drive.kyiv_drive.service.stop;

import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

public record StopImportDataset(
        List<ParsedStop> stops,
        int totalFeatureCount,
        int outOfBoundsFeatureCount,
        String fileHash
) {
    public StopImportDataset {
        stops = List.copyOf(stops);
    }

    public Set<Long> osmIds() {
        return stops.stream()
                .map(ParsedStop::osmId)
                .collect(Collectors.toUnmodifiableSet());
    }
}
