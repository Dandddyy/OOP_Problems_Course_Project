package ua.kyiv.drive.kyiv_drive.service.search.scoring;

import ua.kyiv.drive.kyiv_drive.model.search.SearchPoint;
import ua.kyiv.drive.kyiv_drive.model.search.SearchTripCandidate;
import ua.kyiv.drive.kyiv_drive.model.search.WalkingMetric;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.DayOfWeek;
import java.util.List;
import java.util.Set;

public record ScoredTrip(SearchTripCandidate trip, SearchPoint pickup, SearchPoint dropoff,
                         WalkingMetric walkingToPickup, WalkingMetric walkingFromDropoff,
                         List<MatchedOccurrence> occurrences, Set<DayOfWeek> matchedWeekdays,
                         BigDecimal fare, double score, ScoreComponents components) {
    public ScoredTrip {
        occurrences = List.copyOf(occurrences);
        matchedWeekdays = Set.copyOf(matchedWeekdays);
    }

    public double displayScore() {
        return BigDecimal.valueOf(score).setScale(1, RoundingMode.HALF_UP).doubleValue();
    }

    public double totalWalkingSeconds() {
        return walkingToPickup.durationSeconds() + walkingFromDropoff.durationSeconds();
    }
}
