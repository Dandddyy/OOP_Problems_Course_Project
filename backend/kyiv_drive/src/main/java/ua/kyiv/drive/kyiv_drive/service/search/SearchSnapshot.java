package ua.kyiv.drive.kyiv_drive.service.search;

import ua.kyiv.drive.kyiv_drive.model.search.*;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

public record SearchSnapshot(UUID ownerId, UUID sessionId, SearchQuery query, List<SearchTripCandidate> candidates,
                             List<WalkingEntry> pickupMetrics, List<WalkingEntry> dropoffMetrics,
                             String graphRevision, String formulaVersion, BigDecimal priceMedian) {
    public record WalkingEntry(SearchCoordinate coordinate, WalkingMetric metric) {
    }

    public Map<SearchCoordinate, WalkingMetric> toPickups() {
        return pickupMetrics.stream().collect(Collectors.toMap(WalkingEntry::coordinate, WalkingEntry::metric));
    }

    public Map<SearchCoordinate, WalkingMetric> fromDropoffs() {
        return dropoffMetrics.stream().collect(Collectors.toMap(WalkingEntry::coordinate, WalkingEntry::metric));
    }

    public static List<WalkingEntry> entries(Map<SearchCoordinate, WalkingMetric> metrics) {
        return metrics.entrySet().stream().map(item -> new WalkingEntry(item.getKey(), item.getValue())).toList();
    }
}
