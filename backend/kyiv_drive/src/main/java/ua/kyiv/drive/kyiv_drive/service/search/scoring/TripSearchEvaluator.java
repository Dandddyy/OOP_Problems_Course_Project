package ua.kyiv.drive.kyiv_drive.service.search.scoring;

import ua.kyiv.drive.kyiv_drive.config.OperationDeadline;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import ua.kyiv.drive.kyiv_drive.config.TripSearchProperties;
import ua.kyiv.drive.kyiv_drive.entity.TripPricingType;
import ua.kyiv.drive.kyiv_drive.entity.TripScheduleType;
import ua.kyiv.drive.kyiv_drive.model.search.*;
import ua.kyiv.drive.kyiv_drive.validation.RoutePolicy;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.DayOfWeek;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.util.*;
import java.util.function.Consumer;
import java.util.stream.Collectors;

/** Evaluates every feasible pair; this component performs no I/O. */
@Service
@RequiredArgsConstructor
public class TripSearchEvaluator {
    private static final BigDecimal TWO = BigDecimal.valueOf(2);
    private static final BigDecimal METERS_PER_KILOMETER = BigDecimal.valueOf(1000);
    private static final Comparator<FeasiblePair> PAIR_TIE_BREAK =
            Comparator.comparingDouble(FeasiblePair::totalWalkingSeconds).thenComparing(FeasiblePair::fare)
                    .thenComparingInt(pair -> pair.pickup().sequenceNumber())
                    .thenComparingInt(pair -> pair.dropoff().sequenceNumber());
    private final TripSearchProperties properties;

    public ScoredSearch evaluate(List<SearchTripCandidate> candidates, SearchQuery query,
                                 Map<SearchCoordinate, WalkingMetric> toPickups,
                                 Map<SearchCoordinate, WalkingMetric> fromDropoffs,
                                 Instant now, BigDecimal frozenPriceMedian) {
        Map<SearchPriority, Double> weights = weights(query);
        Set<LocalDate> anchors = Set.copyOf(query.anchorDates());
        if (anchors.isEmpty()) {
            return new ScoredSearch(List.of(), frozenPriceMedian);
        }

        Map<UUID, List<SearchTripCandidate>> byTrip = new LinkedHashMap<>();
        for (SearchTripCandidate candidate : candidates) {
            OperationDeadline.check();
            byTrip.computeIfAbsent(candidate.tripId(), ignored -> new ArrayList<>()).add(candidate);
        }

        boolean needsPriceMedian = frozenPriceMedian == null && byTrip.size() > 1;
        List<BigDecimal> tripMedians = new ArrayList<>();
        List<FeasiblePair> bestPairs = new ArrayList<>();
        for (List<SearchTripCandidate> tripCandidates : byTrip.values()) {
            BestPairCollector collector = new BestPairCollector(weights);
            // Each trip contributes one median regardless of its number of feasible pairs.
            List<BigDecimal> fares = new ArrayList<>();
            for (SearchTripCandidate candidate : tripCandidates) {
                forEachFeasiblePair(candidate, query, anchors, toPickups, fromDropoffs, now, weights, pair -> {
                    collector.accept(pair);
                    if (needsPriceMedian) fares.add(pair.fare());
                });
            }
            if (collector.best == null) continue;
            bestPairs.add(collector.best);
            if (needsPriceMedian) tripMedians.add(median(fares));
        }

        BigDecimal priceMedian = tripMedians.size() > 1 ? median(tripMedians) : frozenPriceMedian;
        List<ScoredTrip> bestTrips = new ArrayList<>(bestPairs.size());
        for (FeasiblePair pair : bestPairs) {
            OperationDeadline.check();
            bestTrips.add(rankTrip(pair, priceMedian, weights));
        }
        bestTrips.sort(resultComparator(query.sort()));
        return new ScoredSearch(bestTrips, priceMedian);
    }

    public Map<SearchPriority, Double> weights(SearchQuery query) {
        List<SearchPriority> enabled = SearchPreferences.DEFAULT_ORDER.stream()
                .filter(priority -> priority != SearchPriority.WEEKDAYS
                        || query.scheduleType() == TripScheduleType.RECURRING).toList();
        SearchPreferences preferences = query.preferences();
        EnumMap<SearchPriority, Double> result = new EnumMap<>(SearchPriority.class);
        if (preferences.priority() == SearchPriority.BALANCED) {
            enabled.forEach(priority -> result.put(priority, 1.0 / enabled.size()));
        } else if (preferences.hasCustomOrder()) {
            List<SearchPriority> order = preferences.order().stream().filter(enabled::contains).toList();
            List<Double> ranked = query.scheduleType() == TripScheduleType.RECURRING
                    ? properties.getRegularRankWeights() : properties.getOneTimeRankWeights();
            if (order.size() != enabled.size() || new HashSet<>(order).size() != enabled.size()
                    || ranked.size() != enabled.size()
                    || ranked.stream().anyMatch(value -> value == null || !Double.isFinite(value) || value <= 0)) {
                throw new IllegalStateException("Invalid search priority weights");
            }
            double sum = ranked.stream().mapToDouble(Double::doubleValue).sum();
            for (int index = 0; index < order.size(); index++) {
                result.put(order.get(index), ranked.get(index) / sum);
            }
        } else {
            double main = properties.getMainPriorityWeight();
            if (!enabled.contains(preferences.priority()) || !Double.isFinite(main) || main <= 0 || main >= 1) {
                throw new IllegalStateException("Invalid main search priority");
            }
            enabled.forEach(priority -> result.put(priority, priority == preferences.priority()
                    ? main : (1 - main) / (enabled.size() - 1)));
        }
        return Collections.unmodifiableMap(result);
    }

    private void forEachFeasiblePair(SearchTripCandidate trip, SearchQuery query, Set<LocalDate> anchors,
                                     Map<SearchCoordinate, WalkingMetric> toPickups,
                                     Map<SearchCoordinate, WalkingMetric> fromDropoffs, Instant now,
                                     Map<SearchPriority, Double> weights, Consumer<FeasiblePair> consumer) {
        for (SearchPoint pickup : trip.pickups()) {
            OperationDeadline.check();
            WalkingMetric toPickup = requireMetric(toPickups, pickup.coordinate());
            if (!allowedWalking(toPickup, query)) continue;
            for (SearchPoint dropoff : trip.dropoffs()) {
                if (pickup.sequenceNumber() >= dropoff.sequenceNumber()
                        || pickup.cumulativeDurationSeconds() > dropoff.cumulativeDurationSeconds()
                        || (long) dropoff.cumulativeDistanceMeters() - pickup.cumulativeDistanceMeters()
                        < RoutePolicy.PASSENGER_MIN_DISTANCE_METERS) continue;
                WalkingMetric fromDropoff = requireMetric(fromDropoffs, dropoff.coordinate());
                if (!allowedWalking(fromDropoff, query)
                        || toPickup.durationSeconds() + fromDropoff.durationSeconds()
                        > query.maxTotalWalkSeconds()) continue;
                List<MatchedOccurrence> matches = matchOccurrences(trip.occurrences(), pickup, dropoff,
                        toPickup, fromDropoff, query, anchors, now, weights);
                if (matches.isEmpty()) continue;

                double departure = matches.stream().mapToDouble(match -> departureScore(match, query)).average()
                        .orElseThrow();
                double arrival = matches.stream().mapToDouble(match -> arrivalScore(match, query)).average()
                        .orElseThrow();
                double walking = Math.exp(-(toPickup.durationSeconds() + fromDropoff.durationSeconds())
                        / properties.getWalkingScaleSeconds());
                double coverage = (double) matches.size() / anchors.size();
                consumer.accept(new FeasiblePair(trip, pickup, dropoff, toPickup, fromDropoff, matches,
                        fare(trip, pickup, dropoff), departure, arrival, walking, coverage));
            }
        }
    }

    private List<MatchedOccurrence> matchOccurrences(List<SearchOccurrence> occurrences, SearchPoint pickup,
                                                     SearchPoint dropoff, WalkingMetric toPickup,
                                                     WalkingMetric fromDropoff, SearchQuery query,
                                                     Set<LocalDate> anchors, Instant now,
                                                     Map<SearchPriority, Double> weights) {
        Map<LocalDate, MatchedOccurrence> byRequestedDate = new TreeMap<>();
        Instant earliestBoarding = now.plusSeconds(SearchPolicy.MIN_BOARDING_LEAD_SECONDS);
        long toSeconds = (long) Math.ceil(toPickup.durationSeconds());
        long fromSeconds = (long) Math.ceil(fromDropoff.durationSeconds());
        long deviation = query.timeDeviationMinutes() * 60L;
        for (SearchOccurrence occurrence : occurrences) {
            if (!anchors.contains(occurrence.requestedDate())) continue;
            Instant board = occurrence.departureAt().plusSeconds(pickup.cumulativeDurationSeconds());
            if (board.isBefore(earliestBoarding)) continue;
            Instant leave = board.minusSeconds(toSeconds);
            if (leave.isBefore(now)) continue;
            Instant alight = occurrence.departureAt().plusSeconds(dropoff.cumulativeDurationSeconds());
            Instant arrive = alight.plusSeconds(fromSeconds);
            Instant departureTarget = query.departureTarget(occurrence.requestedDate());
            Instant arrivalTarget = query.arrivalTarget(occurrence.requestedDate());
            if (!withinWindow(leave, departureTarget, deviation)
                    && !withinWindow(arrive, arrivalTarget, deviation)) continue;
            MatchedOccurrence match = new MatchedOccurrence(occurrence, leave, board, alight, arrive);
            byRequestedDate.merge(occurrence.requestedDate(), match,
                    (existing, proposed) -> occurrenceValue(proposed, query, weights)
                            > occurrenceValue(existing, query, weights) ? proposed : existing);
        }
        return List.copyOf(byRequestedDate.values());
    }

    private double occurrenceValue(MatchedOccurrence match, SearchQuery query, Map<SearchPriority, Double> weights) {
        return departureScore(match, query) * weights.get(SearchPriority.DEPARTURE)
                + arrivalScore(match, query) * weights.get(SearchPriority.ARRIVAL);
    }

    private double departureScore(MatchedOccurrence match, SearchQuery query) {
        double deviation = secondsBetween(query.departureTarget(match.requestedDate()), match.leaveAt());
        return Math.exp(-Math.abs(deviation) / (deviation < 0
                ? properties.getDepartureEarlyScaleSeconds() : properties.getDepartureLateScaleSeconds()));
    }

    private double arrivalScore(MatchedOccurrence match, SearchQuery query) {
        double late = Math.max(0, secondsBetween(query.arrivalTarget(match.requestedDate()), match.arriveAt()));
        return Math.exp(-late / properties.getArrivalLateScaleSeconds());
    }

    private boolean withinWindow(Instant actual, Instant target, long deviationSeconds) {
        return !actual.isBefore(target.minusSeconds(deviationSeconds))
                && !actual.isAfter(target.plusSeconds(deviationSeconds));
    }

    private double secondsBetween(Instant start, Instant end) {
        Duration duration = Duration.between(start, end);
        return duration.getSeconds() + duration.getNano() / 1_000_000_000.0;
    }

    private boolean allowedWalking(WalkingMetric metric, SearchQuery query) {
        return metric.reachable() && Double.isFinite(metric.distanceMeters()) && Double.isFinite(metric.durationSeconds())
                && metric.distanceMeters() >= 0 && metric.durationSeconds() >= 0
                && metric.distanceMeters() <= query.maxWalkMeters() && metric.durationSeconds() <= query.maxWalkSeconds();
    }

    private WalkingMetric requireMetric(Map<SearchCoordinate, WalkingMetric> metrics, SearchCoordinate coordinate) {
        WalkingMetric metric = metrics.get(coordinate);
        if (metric == null) throw new IllegalStateException("Walking metrics do not cover the selected points");
        return metric;
    }

    private BigDecimal fare(SearchTripCandidate trip, SearchPoint pickup, SearchPoint dropoff) {
        if (trip.pricingType() == TripPricingType.FIXED) return trip.priceAmount().setScale(2, RoundingMode.HALF_UP);
        return trip.priceAmount().multiply(BigDecimal.valueOf(
                        (long) dropoff.cumulativeDistanceMeters() - pickup.cumulativeDistanceMeters()))
                .divide(METERS_PER_KILOMETER, 2, RoundingMode.HALF_UP);
    }

    private BigDecimal median(List<BigDecimal> values) {
        List<BigDecimal> sorted = values.stream().sorted().toList();
        int middle = sorted.size() / 2;
        return sorted.size() % 2 == 1 ? sorted.get(middle)
                : sorted.get(middle - 1).add(sorted.get(middle)).divide(TWO);
    }

    private double priceScore(BigDecimal fare, BigDecimal median) {
        if (median == null) return 0.5;
        if (median.signum() <= 0) return fare.signum() == 0 ? 1 : 0;
        return Math.exp(-Math.log(2) * fare.doubleValue() / median.doubleValue());
    }

    private double weightedValue(FeasiblePair pair, double priceValue, Map<SearchPriority, Double> weights) {
        return weights.get(SearchPriority.DEPARTURE) * pair.departureScore()
                + weights.get(SearchPriority.ARRIVAL) * pair.arrivalScore()
                + weights.get(SearchPriority.WALKING) * pair.walkingScore()
                + weights.get(SearchPriority.PRICE) * priceValue
                + weights.getOrDefault(SearchPriority.WEEKDAYS, 0.0) * pair.coverage();
    }

    private double pairValue(FeasiblePair pair, Map<SearchPriority, Double> weights) {
        double durationPenalty = journeyDurationSeconds(pair) / properties.getPairDurationScaleSeconds();
        // A linear fare penalty makes the difference between two pairs depend on their surcharge.
        double farePenalty = pair.fare().doubleValue() / properties.getPairFareScaleUah();
        return weightedValue(pair, -farePenalty, weights) - durationPenalty;
    }

    private double journeyDurationSeconds(FeasiblePair pair) {
        // The same stop offsets and walking durations apply on every matched date.
        MatchedOccurrence occurrence = pair.occurrences().getFirst();
        return secondsBetween(occurrence.leaveAt(), occurrence.arriveAt());
    }

    private ScoredTrip rankTrip(FeasiblePair pair, BigDecimal priceMedian, Map<SearchPriority, Double> weights) {
        double price = priceScore(pair.fare(), priceMedian);
        double duration = 1 / (1 + journeyDurationSeconds(pair) / properties.getRankingDurationScaleSeconds());
        double durationWeight = properties.getRankingDurationWeight();
        double value = (1 - durationWeight) * weightedValue(pair, price, weights) + durationWeight * duration;
        double score = 10 * Math.clamp(value, 0, 1);
        ScoreComponents components = new ScoreComponents(pair.departureScore(), pair.arrivalScore(),
                pair.walkingScore(), pair.coverage(), price, duration);
        Set<DayOfWeek> matchedWeekdays = pair.occurrences().stream().map(match -> match.requestedDate().getDayOfWeek())
                .collect(Collectors.toCollection(() -> EnumSet.noneOf(DayOfWeek.class)));
        return new ScoredTrip(pair.trip(), pair.pickup(), pair.dropoff(), pair.toPickup(), pair.fromDropoff(),
                pair.occurrences(), matchedWeekdays, pair.fare(), score, components);
    }

    private Comparator<ScoredTrip> resultComparator(SearchSort sort) {
        Comparator<ScoredTrip> tieBreak = Comparator.comparingDouble(ScoredTrip::score).reversed()
                .thenComparing(trip -> trip.trip().tripId());
        return switch (sort) {
            case SCORE -> tieBreak;
            case PRICE -> Comparator.comparing(ScoredTrip::fare).thenComparing(tieBreak);
            case WALKING -> Comparator.comparingDouble(ScoredTrip::totalWalkingSeconds).thenComparing(tieBreak);
            case DEPARTURE -> Comparator.comparing((ScoredTrip trip) -> trip.occurrences().getFirst().leaveAt())
                    .thenComparing(tieBreak);
            case ARRIVAL -> Comparator.comparing((ScoredTrip trip) -> trip.occurrences().getFirst().arriveAt())
                    .thenComparing(tieBreak);
        };
    }

    private final class BestPairCollector implements Consumer<FeasiblePair> {
        private final Map<SearchPriority, Double> weights;
        private FeasiblePair best;
        private double bestValue;

        private BestPairCollector(Map<SearchPriority, Double> weights) {
            this.weights = weights;
        }

        @Override
        public void accept(FeasiblePair pair) {
            double value = pairValue(pair, weights);
            if (best == null || value > bestValue || (value == bestValue && PAIR_TIE_BREAK.compare(pair, best) < 0)) {
                best = pair;
                bestValue = value;
            }
        }
    }

    private record FeasiblePair(SearchTripCandidate trip, SearchPoint pickup, SearchPoint dropoff,
                                 WalkingMetric toPickup, WalkingMetric fromDropoff,
                                 List<MatchedOccurrence> occurrences, BigDecimal fare, double departureScore,
                                 double arrivalScore, double walkingScore, double coverage) {
        private double totalWalkingSeconds() {
            return toPickup.durationSeconds() + fromDropoff.durationSeconds();
        }
    }
}
