package ua.kyiv.drive.kyiv_drive.service.search.scoring;

import java.math.BigDecimal;
import java.util.List;

public record ScoredSearch(List<ScoredTrip> trips, BigDecimal priceMedian) {
    public ScoredSearch {
        trips = List.copyOf(trips);
    }
}
