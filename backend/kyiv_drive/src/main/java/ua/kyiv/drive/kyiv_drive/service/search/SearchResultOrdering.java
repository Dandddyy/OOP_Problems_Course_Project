package ua.kyiv.drive.kyiv_drive.service.search;

import org.springframework.stereotype.Component;
import ua.kyiv.drive.kyiv_drive.model.search.SearchSort;

import java.util.Comparator;
import java.util.List;
import java.util.stream.IntStream;

@Component
public class SearchResultOrdering {
    public List<Integer> order(SearchRanking ranking, SearchSort sort) {
        Comparator<SearchRanking.Hit> tieBreak = Comparator.comparingDouble(SearchRanking.Hit::exactScore).reversed()
                .thenComparing(hit -> hit.result().tripId());
        Comparator<SearchRanking.Hit> comparator = switch (sort) {
            case SCORE -> tieBreak;
            case PRICE -> Comparator.comparing((SearchRanking.Hit hit) -> hit.result().priceAmount()).thenComparing(tieBreak);
            case WALKING -> Comparator.comparingDouble((SearchRanking.Hit hit) ->
                    hit.result().walkingToPickup().durationSeconds() + hit.result().walkingFromDropoff().durationSeconds())
                    .thenComparing(tieBreak);
            case DEPARTURE -> Comparator.comparing((SearchRanking.Hit hit) -> hit.result().occurrences().getFirst().leaveAt())
                    .thenComparing(tieBreak);
            case ARRIVAL -> Comparator.comparing((SearchRanking.Hit hit) -> hit.result().occurrences().getFirst().arriveAt())
                    .thenComparing(tieBreak);
        };
        return IntStream.range(0, ranking.hits().size()).boxed()
                .sorted((left, right) -> comparator.compare(ranking.hits().get(left), ranking.hits().get(right))).toList();
    }
}
