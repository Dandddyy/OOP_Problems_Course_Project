package ua.kyiv.drive.kyiv_drive.service.search;

import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import ua.kyiv.drive.kyiv_drive.config.TripSearchProperties;
import ua.kyiv.drive.kyiv_drive.dto.search.TripSearchRequestDTO;
import ua.kyiv.drive.kyiv_drive.dto.search.TripSearchPreferencesDTO;
import ua.kyiv.drive.kyiv_drive.dto.search.TripSearchFiltersDTO;
import ua.kyiv.drive.kyiv_drive.entity.TripScheduleType;
import ua.kyiv.drive.kyiv_drive.exception.TripSearchException;
import ua.kyiv.drive.kyiv_drive.model.search.*;
import ua.kyiv.drive.kyiv_drive.validation.RouteWaypointValidator;
import ua.kyiv.drive.kyiv_drive.validation.ServiceArea;
import ua.kyiv.drive.kyiv_drive.validation.TripPolicy;

import java.time.Instant;
import java.time.LocalDate;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/** Search business rules applied after DTO constraint validation. */
@Component
@RequiredArgsConstructor
public class TripSearchRequestValidator {
    private final TripSearchProperties properties;

    public SearchQuery validate(TripSearchRequestDTO request, Instant now) {
        if (!ServiceArea.contains(request.getOriginLat(), request.getOriginLon())
                || !ServiceArea.contains(request.getDestinationLat(), request.getDestinationLon())) {
            throw invalid();
        }
        RouteWaypointValidator.validate(request.getOriginLat(), request.getOriginLon(),
                request.getDestinationLat(), request.getDestinationLon(), List.of());
        LocalDate today = now.atZone(TripPolicy.TIME_ZONE).toLocalDate();
        if (request.getDate().isBefore(today)) {
            throw departureInPast();
        }
        if (request.getDate().isAfter(today.plusDays(TripPolicy.MAX_DEPARTURE_DAYS_AHEAD))) {
            throw invalid();
        }
        boolean regular = request.getScheduleType() == TripScheduleType.RECURRING;
        if (regular && !request.getWeekdays().contains(request.getDate().getDayOfWeek())) {
            throw new TripSearchException("trip_recurring_days_invalid", HttpStatus.BAD_REQUEST);
        }
        if (!regular && !request.getWeekdays().isEmpty()) {
            throw new TripSearchException("trip_one_time_days_invalid", HttpStatus.BAD_REQUEST);
        }
        int dayOffset = request.getArrivalDayOffset() == null
                ? (request.getArrivalLocalTime().isBefore(request.getDepartureLocalTime()) ? 1 : 0)
                : request.getArrivalDayOffset();
        if (dayOffset == 0 && request.getArrivalLocalTime().isBefore(request.getDepartureLocalTime())) {
            throw invalid();
        }
        SearchQuery query = new SearchQuery(new SearchCoordinate(request.getOriginLon(), request.getOriginLat()),
                new SearchCoordinate(request.getDestinationLon(), request.getDestinationLat()),
                request.getScheduleType(), request.getDate(), request.getDepartureLocalTime(),
                request.getArrivalLocalTime(), dayOffset, regular ? Set.copyOf(request.getWeekdays()) : Set.of(),
                bounded(request.getMaxWalkMeters(), properties.getDefaultWalkMeters(), properties.getMaxAllowedWalkMeters()),
                bounded(request.getMaxWalkSeconds(), properties.getDefaultWalkSeconds(), properties.getMaxAllowedWalkSeconds()),
                bounded(request.getMaxTotalWalkSeconds(), properties.getDefaultTotalWalkSeconds(), properties.getMaxAllowedTotalWalkSeconds()),
                bounded(request.getTimeDeviationMinutes(), properties.getDefaultDeviationMinutes(), properties.getMaxDeviationMinutes()),
                regular ? properties.getHorizonDays() : 1,
                preferences(request.getPriority(), request.getOrder(), request.isHasCustomOrder(), regular),
                bounded(request.getPageSize(), properties.getDefaultPageSize(), properties.getMaxPageSize()),
                request.getSort());
        for (LocalDate anchor : query.anchorDates()) {
            if (TripPolicy.TIME_ZONE.getRules().getValidOffsets(anchor.atTime(query.departureLocalTime())).isEmpty()
                    || TripPolicy.TIME_ZONE.getRules().getValidOffsets(
                    anchor.plusDays(dayOffset).atTime(query.arrivalLocalTime())).isEmpty()) {
                throw invalid();
            }
        }
        if (!query.departureTarget(query.date()).isAfter(now)) {
            throw departureInPast();
        }
        return query;
    }

    public SearchPreferences preferences(SearchPriority priority, List<SearchPriority> order,
                                         boolean custom, boolean regular) {
        if (order.contains(SearchPriority.BALANCED) || new HashSet<>(order).size() != order.size()
                || !SearchPreferences.DEFAULT_ORDER.containsAll(order)
                || !regular && priority == SearchPriority.WEEKDAYS) {
            throw invalid();
        }
        List<SearchPriority> visible = order.stream().filter(item -> regular || item != SearchPriority.WEEKDAYS).toList();
        List<SearchPriority> expected = SearchPreferences.DEFAULT_ORDER.stream()
                .filter(item -> regular || item != SearchPriority.WEEKDAYS).toList();
        if (visible.size() != expected.size() || !visible.containsAll(expected)
                || custom && priority != SearchPriority.BALANCED && visible.getFirst() != priority) {
            throw invalid();
        }
        return new SearchPreferences(priority, visible, custom);
    }

    public SearchQuery variant(SearchQuery original, SearchQuery current, TripSearchPreferencesDTO request) {
        SearchQuery previous = request.isReplace() ? original : current;
        SearchPreferences old = previous.preferences();
        SearchPreferences prefs = preferences(request.getPriority() == null ? old.priority() : request.getPriority(),
                request.getOrder() == null ? old.order() : request.getOrder(),
                request.getHasCustomOrder() == null ? old.hasCustomOrder() : request.getHasCustomOrder(),
                original.scheduleType() == TripScheduleType.RECURRING);
        TripSearchFiltersDTO filters = request.getFilters();
        return new SearchQuery(original.origin(), original.destination(), original.scheduleType(), original.date(),
                original.departureLocalTime(), original.arrivalLocalTime(), original.arrivalDayOffset(), original.weekdays(),
                narrowed(filters == null ? null : filters.getMaxWalkMeters(), previous.maxWalkMeters(), original.maxWalkMeters()),
                narrowed(filters == null ? null : filters.getMaxWalkSeconds(), previous.maxWalkSeconds(), original.maxWalkSeconds()),
                narrowed(filters == null ? null : filters.getMaxTotalWalkSeconds(), previous.maxTotalWalkSeconds(), original.maxTotalWalkSeconds()),
                narrowed(filters == null ? null : filters.getTimeDeviationMinutes(), previous.timeDeviationMinutes(), original.timeDeviationMinutes()),
                original.horizonDays(), prefs, original.pageSize(), SearchSort.SCORE);
    }

    private int narrowed(Integer value, int previous, int original) {
        if (value == null) return previous;
        if (value > original) throw new TripSearchException("trip_search_new_search_required", HttpStatus.CONFLICT);
        return value;
    }

    private int bounded(Integer supplied, int fallback, int maximum) {
        int value = supplied == null ? fallback : supplied;
        if (value > maximum) throw invalid();
        return value;
    }

    private TripSearchException invalid() {
        return new TripSearchException("trip_search_invalid_request", HttpStatus.BAD_REQUEST);
    }

    private TripSearchException departureInPast() {
        return new TripSearchException("trip_departure_in_past", HttpStatus.BAD_REQUEST);
    }
}
