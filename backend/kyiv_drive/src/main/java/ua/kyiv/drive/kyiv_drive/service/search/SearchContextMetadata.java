package ua.kyiv.drive.kyiv_drive.service.search;

import ua.kyiv.drive.kyiv_drive.model.search.SearchQuery;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

public record SearchContextMetadata(UUID ownerId, UUID sessionId, SearchQuery query,
                                    String graphRevision, String formulaVersion, BigDecimal priceMedian,
                                    List<Variant> variants, long sequence) {
    public record Variant(UUID id, String fingerprint, long lastUsed) {
    }
}
