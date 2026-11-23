package ua.kyiv.drive.kyiv_drive.service.search;

import ua.kyiv.drive.kyiv_drive.dto.search.TripSearchResultDTO;
import ua.kyiv.drive.kyiv_drive.model.search.SearchQuery;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record SearchRanking(UUID id, SearchQuery query, List<Hit> hits) {
    public record Hit(TripSearchResultDTO result, Instant tripUpdatedAt, double exactScore) {
    }
}
