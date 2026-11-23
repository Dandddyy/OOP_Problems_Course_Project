package ua.kyiv.drive.kyiv_drive.service.search.scoring;

import ua.kyiv.drive.kyiv_drive.model.search.SearchOccurrence;

import java.time.Instant;
import java.time.LocalDate;

public record MatchedOccurrence(SearchOccurrence occurrence, Instant leaveAt, Instant boardAt,
                                Instant alightAt, Instant arriveAt) {
    public LocalDate requestedDate() {
        return occurrence.requestedDate();
    }
}
