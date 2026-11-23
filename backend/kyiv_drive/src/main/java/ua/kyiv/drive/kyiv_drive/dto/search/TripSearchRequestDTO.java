package ua.kyiv.drive.kyiv_drive.dto.search;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import lombok.Getter;
import lombok.Setter;
import ua.kyiv.drive.kyiv_drive.entity.TripScheduleType;
import ua.kyiv.drive.kyiv_drive.model.search.SearchPreferences;
import ua.kyiv.drive.kyiv_drive.model.search.SearchPriority;
import ua.kyiv.drive.kyiv_drive.model.search.SearchSort;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Set;
import java.util.UUID;

@Getter
@Setter
public class TripSearchRequestDTO {
    @NotNull(message = "Origin latitude is required")
    private Double originLat;
    @NotNull(message = "Origin longitude is required")
    private Double originLon;
    @NotNull(message = "Destination latitude is required")
    private Double destinationLat;
    @NotNull(message = "Destination longitude is required")
    private Double destinationLon;
    @NotNull(message = "Schedule type is required")
    private TripScheduleType scheduleType;
    @NotNull(message = "Search date is required")
    private LocalDate date;
    @NotNull(message = "Departure time is required")
    private LocalTime departureLocalTime;
    @NotNull(message = "Arrival time is required")
    private LocalTime arrivalLocalTime;
    @Min(value = 0, message = "Arrival day offset cannot be negative")
    @Max(value = 2, message = "Arrival day offset cannot exceed {value}")
    private Integer arrivalDayOffset;
    @NotNull(message = "Weekdays are required")
    private Set<@NotNull(message = "Weekday cannot be null") DayOfWeek> weekdays = Set.of();
    @NotNull(message = "Search priority is required")
    private SearchPriority priority = SearchPriority.BALANCED;
    @NotEmpty(message = "Priority order cannot be empty")
    private List<@NotNull(message = "Priority cannot be null") SearchPriority> order = SearchPreferences.DEFAULT_ORDER;
    private boolean hasCustomOrder;
    @Positive(message = "Maximum walking distance must be positive")
    private Integer maxWalkMeters;
    @Positive(message = "Maximum walking duration must be positive")
    private Integer maxWalkSeconds;
    @Positive(message = "Maximum total walking duration must be positive")
    private Integer maxTotalWalkSeconds;
    @Positive(message = "Time deviation must be positive")
    private Integer timeDeviationMinutes;
    @Positive(message = "Page size must be positive")
    private Integer pageSize;
    @NotNull(message = "Search sort is required")
    private SearchSort sort = SearchSort.SCORE;
    private UUID requestId;
    @Valid
    private TripSearchFiltersDTO filters;
    private UUID anchorTripId;
    @Positive(message = "Restore result count must be positive")
    private Integer restoreResultCount;
}
