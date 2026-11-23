package ua.kyiv.drive.kyiv_drive.dto.search;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

public record TripSearchPageDTO(String searchId, List<TripSearchResultDTO> items, String nextCursor,
                                boolean hasMore, int resultCountAtCreation, Instant expiresAt,
                                String graphRevision, String formulaVersion, BigDecimal priceMedian,
                                AppliedLimits limits, String previousCursor, int startOffset, Integer anchorIndex,
                                AppliedLimits selectionLimits, int pageSize) {
    public TripSearchPageDTO(String searchId, List<TripSearchResultDTO> items, String nextCursor,
                             boolean hasMore, int resultCountAtCreation, Instant expiresAt,
                             String graphRevision, String formulaVersion, BigDecimal priceMedian, AppliedLimits limits) {
        this(searchId, items, nextCursor, hasMore, resultCountAtCreation, expiresAt, graphRevision,
                formulaVersion, priceMedian, limits, null, 0, null, limits, 20);
    }

    public record AppliedLimits(int maxWalkMeters, int maxWalkSeconds, int maxTotalWalkSeconds,
                                int timeDeviationMinutes, int minimumBoardingLeadSeconds, int horizonDays) {
    }
}
