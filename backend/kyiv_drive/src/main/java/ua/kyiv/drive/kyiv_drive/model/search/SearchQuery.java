package ua.kyiv.drive.kyiv_drive.model.search;

import ua.kyiv.drive.kyiv_drive.entity.TripScheduleType;
import ua.kyiv.drive.kyiv_drive.validation.TripPolicy;

import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Set;
import java.util.stream.IntStream;

public record SearchQuery(SearchCoordinate origin, SearchCoordinate destination, TripScheduleType scheduleType,
                          LocalDate date, LocalTime departureLocalTime, LocalTime arrivalLocalTime,
                          int arrivalDayOffset, Set<DayOfWeek> weekdays, int maxWalkMeters, int maxWalkSeconds,
                          int maxTotalWalkSeconds, int timeDeviationMinutes, int horizonDays,
                          SearchPreferences preferences, int pageSize, SearchSort sort) {
    public List<LocalDate> anchorDates() {
        if (scheduleType == TripScheduleType.ONE_TIME) {
            return List.of(date);
        }
        return IntStream.range(0, horizonDays).mapToObj(date::plusDays)
                .filter(day -> weekdays.contains(day.getDayOfWeek())).toList();
    }

    public Instant departureTarget(LocalDate anchor) {
        return anchor.atTime(departureLocalTime).atZone(TripPolicy.TIME_ZONE)
                .withLaterOffsetAtOverlap().toInstant();
    }

    public Instant arrivalTarget(LocalDate anchor) {
        return anchor.plusDays(arrivalDayOffset).atTime(arrivalLocalTime).atZone(TripPolicy.TIME_ZONE)
                .withLaterOffsetAtOverlap().toInstant();
    }
}
