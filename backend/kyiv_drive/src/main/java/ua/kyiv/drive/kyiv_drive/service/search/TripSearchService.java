package ua.kyiv.drive.kyiv_drive.service.search;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import ua.kyiv.drive.kyiv_drive.config.OperationDeadline;
import ua.kyiv.drive.kyiv_drive.config.TripSearchProperties;
import ua.kyiv.drive.kyiv_drive.dto.map.RouteRequestDTO;
import ua.kyiv.drive.kyiv_drive.dto.search.*;
import ua.kyiv.drive.kyiv_drive.dto.search.TripSearchResultDTO.OccurrenceDTO;
import ua.kyiv.drive.kyiv_drive.dto.search.TripSearchResultDTO.PreferenceMatchDTO;
import ua.kyiv.drive.kyiv_drive.dto.search.TripSearchResultDTO.ScheduleMatch;
import ua.kyiv.drive.kyiv_drive.entity.TripScheduleType;
import ua.kyiv.drive.kyiv_drive.exception.IdempotencyConflictException;
import ua.kyiv.drive.kyiv_drive.exception.SessionNotActiveException;
import ua.kyiv.drive.kyiv_drive.exception.TripSearchException;
import ua.kyiv.drive.kyiv_drive.mapper.TripSearchMapper;
import ua.kyiv.drive.kyiv_drive.model.search.*;
import ua.kyiv.drive.kyiv_drive.repository.TripRepository;
import ua.kyiv.drive.kyiv_drive.repository.UserSessionRepository;
import ua.kyiv.drive.kyiv_drive.service.MapService;
import ua.kyiv.drive.kyiv_drive.service.execution.OperationPlan;
import ua.kyiv.drive.kyiv_drive.service.execution.OperationProfile;
import ua.kyiv.drive.kyiv_drive.service.limit.RequestRateLimits;
import ua.kyiv.drive.kyiv_drive.service.search.scoring.*;
import ua.kyiv.drive.kyiv_drive.service.search.walking.*;
import ua.kyiv.drive.kyiv_drive.validation.RoutePolicy;
import ua.kyiv.drive.kyiv_drive.validation.TripPolicy;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.util.*;

@Service
@Slf4j
@RequiredArgsConstructor
public class TripSearchService {
    private final TripRepository repository;
    private final UserSessionRepository sessions;
    private final TripSearchRequestValidator validator;
    private final MapService mapService;
    private final WalkingRoutingService walking;
    private final TripSearchEvaluator evaluator;
    private final TripSearchMapper mapper;
    private final SearchSnapshotStore snapshots;
    private final SearchResultOrdering ordering;
    private final TripSearchProperties properties;
    private final Clock clock;
    private final RequestRateLimits rateLimits;

    public TripSearchPageDTO search(TripSearchRequestDTO request, UUID userId, UUID sessionId) {
        return prepareSearch(request, userId, sessionId).action().get();
    }

    public OperationPlan<TripSearchPageDTO> prepareSearch(TripSearchRequestDTO request, UUID userId, UUID sessionId) {
        requireSession(userId, sessionId);
        SearchQuery query = validator.validate(request, clock.instant());
        var applied = new TripSearchPreferencesDTO();
        applied.setFilters(request.getFilters());
        SearchQuery variantQuery = validator.variant(query, query, applied);
        int restoreCount = request.getRestoreResultCount() == null ? query.pageSize() : request.getRestoreResultCount();
        if (restoreCount > properties.getMaxRestoreItems()) {
            throw new TripSearchException("trip_search_invalid_request", HttpStatus.BAD_REQUEST);
        }
        String requestFingerprint = creationFingerprint(query, variantQuery, request, restoreCount);
        TripSearchPageDTO replay = replay(request, requestFingerprint, restoreCount, userId, sessionId);
        if (replay != null) return OperationPlan.cached(() -> replay);
        var pending = snapshots.beginSearch(userId, sessionId);
        return new OperationPlan<>(OperationProfile.SEARCH, () -> {
            snapshots.requirePending(userId, sessionId, pending.contextId());
            TripSearchPageDTO repeated = replay(request, requestFingerprint, restoreCount, userId, sessionId);
            if (repeated != null) return repeated;
            long started = System.nanoTime();
            mapService.getRouteForSearch(new RouteRequestDTO(query.origin().latitude(), query.origin().longitude(),
                    query.destination().latitude(), query.destination().longitude(), List.of()), userId);
            snapshots.requirePending(userId, sessionId, pending.contextId());
            long validated = System.nanoTime();
            OperationDeadline.check();
            List<SearchTripCandidate> candidates = repository.findCandidates(query, userId, clock.instant());
            long selected = System.nanoTime();
            Set<SearchCoordinate> pickups = new LinkedHashSet<>();
            Set<SearchCoordinate> dropoffs = new LinkedHashSet<>();
            OperationDeadline.check();
            candidates.forEach(trip -> {
                trip.pickups().forEach(point -> pickups.add(point.coordinate()));
                trip.dropoffs().forEach(point -> dropoffs.add(point.coordinate()));
            });
            WalkingRoutes routes = walking.calculate(query.origin(), query.destination(), pickups, dropoffs);
            long routed = System.nanoTime();
            ScoredSearch scored = evaluator.evaluate(candidates, variantQuery, routes.toPickups(), routes.fromDropoffs(),
                    clock.instant(), null);
            var snapshot = new SearchSnapshot(userId, sessionId, query, candidates,
                    SearchSnapshot.entries(routes.toPickups()), SearchSnapshot.entries(routes.fromDropoffs()),
                    routes.graphRevision(), formulaVersion(), scored.priceMedian());
            SearchRanking ranking = ranking(variantQuery, scored.trips());
            SearchHandle handle = new SearchHandle(pending.contextId(), ranking.id(), query.sort());
            List<Integer> order = ordering.order(ranking, handle.sort());
            PageSlice slice = pageItems(ranking, order, userId, creationWindow(ranking, order, request, restoreCount));
            requireCurrent(snapshot.graphRevision(), snapshot.formulaVersion());
            requireSession(userId, sessionId);
            SearchRequestIdentity identity = request.getRequestId() == null ? null
                    : new SearchRequestIdentity(request.getRequestId(), requestFingerprint, handle.encode());
            Instant expires = snapshots.publish(userId, sessionId, handle, snapshot, ranking, order,
                    fingerprint(variantQuery), pending.previousContext(), identity);
            log.debug("Trip search: candidates={}, pickupPoints={}, dropoffPoints={}, results={}, validationMs={}, sqlMs={}, walkingMs={}, remainingMs={}",
                    candidates.size(), pickups.size(), dropoffs.size(), scored.trips().size(),
                    (validated - started) / 1_000_000, (selected - validated) / 1_000_000, (routed - selected) / 1_000_000,
                    (System.nanoTime() - routed) / 1_000_000);
            return pageResponse(handle, ranking, slice, expires, snapshot.graphRevision(), snapshot.formulaVersion(), snapshot.priceMedian(), snapshot.query());
        });
    }

    public TripSearchPageDTO page(String searchId, String cursor, UUID userId, UUID sessionId) {
        requireSession(userId, sessionId);
        SearchHandle handle = SearchHandle.parse(searchId);
        SearchContextMetadata metadata = metadata(handle, userId, sessionId);
        SearchRanking ranking = requireRanking(handle, userId, sessionId);
        return cachedPage(handle, ranking, metadata, decodeCursor(cursor, searchId, ranking.query().pageSize()), userId, sessionId);
    }

    public TripSearchKeepAliveDTO keepAlive(String searchId, UUID userId, UUID sessionId) {
        requireSession(userId, sessionId);
        SearchHandle handle = SearchHandle.parse(searchId);
        metadata(handle, userId, sessionId);
        rateLimits.keepAlive(userId, sessionId, handle.contextId());
        Instant expires = snapshots.touch(userId, sessionId, handle);
        return new TripSearchKeepAliveDTO(searchId, expires);
    }

    public TripSearchPageDTO reprioritize(String searchId, TripSearchPreferencesDTO request,
                                          UUID userId, UUID sessionId) {
        return prepareReprioritization(searchId, request, userId, sessionId).action().get();
    }

    public OperationPlan<TripSearchPageDTO> prepareReprioritization(String searchId, TripSearchPreferencesDTO request,
                                                                  UUID userId, UUID sessionId) {
        requireSession(userId, sessionId);
        SearchHandle source = SearchHandle.parse(searchId);
        SearchContextMetadata initial = metadata(source, userId, sessionId);
        SearchRanking previous = snapshots.ranking(userId, sessionId, source);
        if (previous == null && !request.isReplace()) {
            metadata(source, userId, sessionId);
            throw SearchSnapshotStore.variantExpired();
        }
        SearchQuery query = validator.variant(initial.query(), previous == null ? initial.query() : previous.query(), request);
        int restoreCount = request.getRestoreResultCount() == null ? query.pageSize() : request.getRestoreResultCount();
        if (restoreCount > properties.getMaxRestoreItems()) {
            throw new TripSearchException("trip_search_invalid_request", HttpStatus.BAD_REQUEST);
        }
        PageWindow requestedWindow = new PageWindow(-1, restoreCount, false, request.getAnchorTripId());
        SearchSort sort = request.getSort() == null ? source.sort() : request.getSort();
        String fingerprint = fingerprint(query);
        var existing = previous != null && fingerprint(previous.query()).equals(fingerprint)
                ? new CachedVariant(new SearchHandle(source.contextId(), previous.id(), sort), previous)
                : cachedVariant(initial, fingerprint, sort, source.contextId(), userId, sessionId);
        if (existing != null) return OperationPlan.cached(() ->
                cachedPage(existing.handle(), existing.ranking(), initial, requestedWindow, userId, sessionId));
        return new OperationPlan<>(OperationProfile.RECALCULATE, () -> {
            var metadata = metadata(source, userId, sessionId);
            var cached = cachedVariant(metadata, fingerprint, sort, source.contextId(), userId, sessionId);
            if (cached != null) return cachedPage(cached.handle(), cached.ranking(), metadata, requestedWindow, userId, sessionId);
            if (!request.isReplace() && snapshots.ranking(userId, sessionId, source) == null) {
                metadata(source, userId, sessionId);
                throw SearchSnapshotStore.variantExpired();
            }
            SearchSnapshot snapshot = snapshots.snapshot(userId, sessionId, source.contextId());
            rateLimits.recalculate(userId);
            List<SearchTripCandidate> current = currentCandidates(snapshot.candidates(), userId);
            ScoredSearch scored = evaluator.evaluate(current, query, snapshot.toPickups(), snapshot.fromDropoffs(),
                    clock.instant(), snapshot.priceMedian());
            SearchRanking ranking = ranking(query, scored.trips());
            SearchHandle handle = new SearchHandle(source.contextId(), ranking.id(), sort);
            List<Integer> order = ordering.order(ranking, sort);
            PageSlice slice = pageItems(ranking, order, userId, restorationWindow(ranking, order, request.getAnchorTripId(), restoreCount));
            requireCurrent(metadata.graphRevision(), metadata.formulaVersion());
            requireSession(userId, sessionId);
            Instant expires;
            try {
                expires = snapshots.saveVariant(userId, sessionId, handle,
                        ranking, order, fingerprint, source.variantId(), request.isReplace());
            } catch (TripSearchException failure) {
                String code = failure.getCode();
                if (!"trip_search_busy".equals(code) && !"trip_search_variant_expired".equals(code)) throw failure;
                var latest = metadata(source, userId, sessionId);
                var saved = cachedVariant(latest, fingerprint, sort, source.contextId(), userId, sessionId);
                if (saved == null) throw SearchSnapshotStore.variantExpired();
                return cachedPage(saved.handle(), saved.ranking(), latest, requestedWindow, userId, sessionId);
            }
            return pageResponse(handle, ranking, slice, expires, metadata.graphRevision(), metadata.formulaVersion(), metadata.priceMedian(), metadata.query());
        });
    }

    private record CachedVariant(SearchHandle handle, SearchRanking ranking) { }

    private CachedVariant cachedVariant(SearchContextMetadata metadata, String fingerprint, SearchSort sort,
                                         UUID context, UUID user, UUID session) {
        for (var variant : metadata.variants()) {
            if (variant.fingerprint().equals(fingerprint)) {
                SearchHandle handle = new SearchHandle(context, variant.id(), sort);
                SearchRanking ranking = snapshots.ranking(user, session, handle);
                if (ranking != null) return new CachedVariant(handle, ranking);
            }
        }
        return null;
    }

    private SearchContextMetadata metadata(SearchHandle handle, UUID user, UUID session) {
        SearchContextMetadata metadata = snapshots.metadata(user, session, handle.contextId());
        if (!metadata.ownerId().equals(user) || !metadata.sessionId().equals(session)) throw SearchSnapshotStore.expired();
        requireCurrent(metadata.graphRevision(), metadata.formulaVersion());
        return metadata;
    }

    private SearchRanking requireRanking(SearchHandle handle, UUID user, UUID session) {
        SearchRanking ranking = snapshots.ranking(user, session, handle);
        if (ranking == null) {
            metadata(handle, user, session);
            throw SearchSnapshotStore.variantExpired();
        }
        return ranking;
    }

    private SearchRanking ranking(SearchQuery query, List<ScoredTrip> trips) {
        return new SearchRanking(UUID.randomUUID(), query, trips.stream().map(trip -> new SearchRanking.Hit(
                mapper.toResult(trip, query), trip.trip().updatedAt(), trip.score())).toList());
    }

    private TripSearchPageDTO cachedPage(SearchHandle handle, SearchRanking ranking, SearchContextMetadata metadata,
                                         PageWindow window, UUID user, UUID session) {
        List<Integer> order = snapshots.order(user, session, handle);
        boolean missing = order == null;
        if (missing) order = ordering.order(ranking, handle.sort());
        if (order.size() != ranking.hits().size()) throw SearchSnapshotStore.variantExpired();
        if (window.offset() < 0) window = restorationWindow(ranking, order, window.anchor(), window.limit());
        PageSlice slice = pageItems(ranking, order, user, window);
        requireCurrent(metadata.graphRevision(), metadata.formulaVersion());
        Instant expires = missing ? snapshots.saveOrder(user, session, handle, order)
                : snapshots.touch(user, session, handle);
        return pageResponse(handle, ranking, slice, expires, metadata.graphRevision(), metadata.formulaVersion(), metadata.priceMedian(), metadata.query());
    }

    private record PageWindow(int offset, int limit, boolean backwards, UUID anchor) { }
    private record PageSlice(List<TripSearchResultDTO> items, int nextOffset, int previousOffset,
                             int startOffset, Integer anchorIndex) { }

    private PageSlice pageItems(SearchRanking ranking, List<Integer> order, UUID owner, PageWindow window) {
        int offset = window.offset();
        if (offset < 0 || offset > order.size()) throw invalidCursor();
        Instant now = clock.instant();
        SearchQuery query = ranking.query();
        List<TripSearchResultDTO> items = new ArrayList<>();
        List<Integer> positions = new ArrayList<>();
        int lookahead = -1;
        int position = offset;
        int batchSize = Math.max(64, query.pageSize() + 1);
        pages:
        while (window.backwards() ? position > 0 : position < order.size()) {
            OperationDeadline.check();
            int start = window.backwards() ? Math.max(0, position - batchSize) : position;
            int end = window.backwards() ? position : Math.min(order.size(), position + batchSize);
            List<UUID> ids = order.subList(start, end).stream()
                    .map(index -> ranking.hits().get(index).result().tripId()).toList();
            Map<UUID, Instant> versions = repository.findCurrentVersions(ids, owner, now);
            Map<UUID, Set<LocalDate>> cancelled = repository.findCancelledDates(ids);
            int index = window.backwards() ? end - 1 : start;
            while (window.backwards() ? index >= start : index < end) {
                SearchRanking.Hit hit = ranking.hits().get(order.get(index));
                TripSearchResultDTO item = hit.result();
                Instant version = versions.get(item.tripId());
                if (version != null) {
                    if (!Objects.equals(hit.tripUpdatedAt(), version)) {
                        throw new TripSearchException("trip_search_changed", HttpStatus.CONFLICT);
                    }
                    Set<LocalDate> exceptions = cancelled.getOrDefault(item.tripId(), Set.of());
                    long currentCount = item.occurrences().stream().filter(occurrence ->
                            !occurrence.boardAt().isBefore(now.plusSeconds(SearchPolicy.MIN_BOARDING_LEAD_SECONDS))
                                    && !occurrence.leaveAt().isBefore(now)
                                    && !exceptions.contains(occurrence.driverDepartureDate())).count();
                    if (currentCount > 0) {
                        if (currentCount != item.occurrences().size()) {
                            throw new TripSearchException("trip_search_changed", HttpStatus.CONFLICT);
                        }
                        if (items.size() == window.limit()) {
                            lookahead = index;
                            break pages;
                        }
                        items.add(mapper.withPreferenceMatch(item, preferenceMatch(item, query)));
                        positions.add(index);
                    }
                }
                index += window.backwards() ? -1 : 1;
            }
            position = window.backwards() ? start : end;
        }
        if (window.backwards()) {
            Collections.reverse(items);
            Collections.reverse(positions);
        }
        int startOffset = window.backwards() ? (positions.isEmpty() ? 0 : positions.getFirst()) : offset;
        int next = window.backwards() ? (offset < order.size() ? offset : -1) : lookahead;
        int previous = window.backwards() ? (lookahead < 0 ? -1 : lookahead + 1) : (offset > 0 ? offset : -1);
        Integer anchorIndex = null;
        if (window.anchor() != null) {
            for (int index = 0; index < items.size(); index++) {
                if (items.get(index).tripId().equals(window.anchor())) { anchorIndex = index; break; }
            }
        }
        return new PageSlice(List.copyOf(items), next, previous, startOffset, anchorIndex);
    }

    private PreferenceMatchDTO preferenceMatch(TripSearchResultDTO item, SearchQuery query) {
        // An arrival within the requested minute counts as on time.
        boolean timeFits = item.occurrences().stream().allMatch(occurrence ->
                !occurrence.leaveAt().isBefore(query.departureTarget(occurrence.requestedDate()))
                        && occurrence.arriveAt().isBefore(query.arrivalTarget(occurrence.requestedDate()).plusSeconds(60)));
        return new PreferenceMatchDTO(timeFits, scheduleMatch(item, query));
    }

    private ScheduleMatch scheduleMatch(TripSearchResultDTO item, SearchQuery query) {
        if (query.scheduleType() != TripScheduleType.RECURRING) return null;
        Instant firstLeaveAt = item.occurrences().stream().map(OccurrenceDTO::leaveAt)
                .min(Comparator.naturalOrder()).orElseThrow();
        if (firstLeaveAt.atZone(TripPolicy.TIME_ZONE).toLocalDate().isAfter(query.date())) {
            return ScheduleMatch.STARTS_LATER;
        }
        if (item.matchedDateCount() < item.requestedDateCount() || !item.matchedWeekdays().containsAll(query.weekdays())) {
            return ScheduleMatch.INCOMPLETE;
        }
        return ScheduleMatch.FITS;
    }

    private PageWindow creationWindow(SearchRanking ranking, List<Integer> order, TripSearchRequestDTO request, int count) {
        return restorationWindow(ranking, order, request.getAnchorTripId(), count);
    }

    private PageWindow restorationWindow(SearchRanking ranking, List<Integer> order, UUID anchor, int count) {
        int offset = 0;
        if (anchor != null) {
            for (int position = 0; position < order.size(); position++) {
                if (ranking.hits().get(order.get(position)).result().tripId().equals(anchor)) {
                    offset = Math.max(0, position - count / 3);
                    break;
                }
            }
        }
        return new PageWindow(offset, count, false, anchor);
    }

    private TripSearchPageDTO replay(TripSearchRequestDTO request, String fingerprint, int count, UUID user, UUID session) {
        if (request.getRequestId() == null) return null;
        UUID context = snapshots.activeContext(user, session);
        if (context == null) return null;
        try {
            SearchContextMetadata metadata = metadata(new SearchHandle(context, context, SearchSort.SCORE), user, session);
            SearchRequestIdentity identity = snapshots.identity(user, session, context);
            if (identity == null || !request.getRequestId().equals(identity.requestId())) return null;
            if (!fingerprint.equals(identity.fingerprint())) {
                throw new IdempotencyConflictException();
            }
            SearchHandle handle = SearchHandle.parse(identity.searchId());
            SearchRanking ranking = snapshots.ranking(user, session, handle);
            if (ranking == null) return null;
            List<Integer> order = snapshots.order(user, session, handle);
            if (order == null) order = ordering.order(ranking, handle.sort());
            return cachedPage(handle, ranking, metadata, creationWindow(ranking, order, request, count), user, session);
        } catch (TripSearchException e) {
            if (e.getCode().equals("trip_search_expired") || e.getCode().equals("trip_search_changed")
                    || e.getCode().equals("trip_search_variant_expired")) return null;
            throw e;
        }
    }

    private TripSearchPageDTO pageResponse(SearchHandle handle, SearchRanking ranking, PageSlice slice, Instant expires,
                                           String graph, String formula, java.math.BigDecimal median, SearchQuery selection) {
        SearchQuery query = ranking.query();
        String searchId = handle.encode();
        return new TripSearchPageDTO(searchId, slice.items(),
                slice.nextOffset() < 0 ? null : encodeCursor(searchId, slice.nextOffset(), false),
                slice.nextOffset() >= 0, ranking.hits().size(), expires, graph, formula,
                median, limits(query), slice.previousOffset() < 0 ? null : encodeCursor(searchId, slice.previousOffset(), true),
                slice.startOffset(), slice.anchorIndex(), limits(selection), query.pageSize());
    }

    private TripSearchPageDTO.AppliedLimits limits(SearchQuery query) {
        return new TripSearchPageDTO.AppliedLimits(query.maxWalkMeters(), query.maxWalkSeconds(),
                query.maxTotalWalkSeconds(), query.timeDeviationMinutes(), SearchPolicy.MIN_BOARDING_LEAD_SECONDS, query.horizonDays());
    }

    private String creationFingerprint(SearchQuery query, SearchQuery variant, TripSearchRequestDTO request, int count) {
        String value = query.origin() + "|" + query.destination() + "|" + query.scheduleType() + "|" + query.date()
                + "|" + query.departureLocalTime() + "|" + query.arrivalLocalTime() + "|" + query.arrivalDayOffset()
                + "|" + query.weekdays().stream().sorted().toList() + "|" + query.maxWalkMeters() + "|" + query.maxWalkSeconds()
                + "|" + query.maxTotalWalkSeconds() + "|" + query.timeDeviationMinutes() + "|" + query.horizonDays()
                + "|" + fingerprint(variant) + "|" + query.pageSize() + "|" + query.sort() + "|" + request.getAnchorTripId() + "|" + count;
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 unavailable", e);
        }
    }

    private String fingerprint(SearchQuery query) {
        String value = query.preferences().priority() + ":" + query.preferences().hasCustomOrder() + ":"
                + query.preferences().order() + ":" + query.maxWalkMeters() + ":" + query.maxWalkSeconds()
                + ":" + query.maxTotalWalkSeconds() + ":" + query.timeDeviationMinutes();
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 unavailable", e);
        }
    }

    private List<SearchTripCandidate> currentCandidates(List<SearchTripCandidate> candidates, UUID owner) {
        List<UUID> ids = candidates.stream().map(SearchTripCandidate::tripId).toList();
        Map<UUID, Instant> versions = repository.findCurrentVersions(ids, owner, clock.instant());
        Map<UUID, Set<LocalDate>> cancelled = repository.findCancelledDates(ids);
        return candidates.stream().filter(trip -> Objects.equals(trip.updatedAt(), versions.get(trip.tripId())))
                .map(trip -> new SearchTripCandidate(trip.tripId(), trip.driverId(), trip.driverName(),
                        trip.driverAvatarUrl(), trip.driverRating(), trip.driverRatingCount(), trip.carId(),
                        trip.carLabel(), trip.pricingType(), trip.priceAmount(), trip.negotiationAllowed(), trip.updatedAt(),
                        trip.pickups(), trip.dropoffs(), trip.occurrences().stream().filter(occurrence ->
                        !cancelled.getOrDefault(trip.tripId(), Set.of()).contains(occurrence.driverDepartureDate())).toList()))
                .toList();
    }

    private void requireSession(UUID user, UUID session) {
        OperationDeadline.check();
        sessions.findActiveCurrentMode(session, user, clock.instant()).orElseThrow(SessionNotActiveException::new);
    }

    private void requireCurrent(String graphRevision, String formulaVersion) {
        if (!formulaVersion.equals(formulaVersion()) || !graphRevision.equals(walking.revision())) {
            throw SearchSnapshotStore.expired();
        }
    }

    private String formulaVersion() {
        String values = RoutePolicy.PASSENGER_MIN_DISTANCE_METERS + ":" + properties.getMainPriorityWeight()
                + ":" + properties.getRegularRankWeights() + ":"
                + properties.getOneTimeRankWeights() + ":" + properties.getDepartureEarlyScaleSeconds() + ":"
                + properties.getDepartureLateScaleSeconds() + ":" + properties.getArrivalLateScaleSeconds() + ":"
                + properties.getWalkingScaleSeconds() + ":" + properties.getPairDurationScaleSeconds() + ":"
                + properties.getPairFareScaleUah() + ":" + properties.getRankingDurationWeight() + ":"
                + properties.getRankingDurationScaleSeconds();
        try {
            return properties.getFormulaVersion() + ":" + HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                    .digest(values.getBytes(StandardCharsets.UTF_8))).substring(0, 16);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 unavailable", e);
        }
    }

    private String encodeCursor(String searchId, int offset, boolean backwards) {
        return Base64.getUrlEncoder().withoutPadding().encodeToString(
                (searchId + ":" + (backwards ? "p" : "n") + ":" + offset).getBytes(StandardCharsets.UTF_8));
    }

    private PageWindow decodeCursor(String cursor, String searchId, int pageSize) {
        if (cursor == null || cursor.isBlank()) return new PageWindow(0, pageSize, false, null);
        if (cursor.length() > 512) throw invalidCursor();
        try {
            String[] parts = new String(Base64.getUrlDecoder().decode(cursor), StandardCharsets.UTF_8).split(":", -1);
            if (parts.length != 3 || !parts[0].equals(searchId)) throw invalidCursor();
            boolean backwards = parts[1].equals("p");
            if (!backwards && !parts[1].equals("n")) throw invalidCursor();
            int offset = Integer.parseInt(parts[2]);
            if (offset < 0) throw invalidCursor();
            return new PageWindow(offset, pageSize, backwards, null);
        } catch (IllegalArgumentException e) {
            throw invalidCursor();
        }
    }

    private TripSearchException invalidCursor() {
        return new TripSearchException("trip_search_invalid_cursor", HttpStatus.BAD_REQUEST);
    }
}
