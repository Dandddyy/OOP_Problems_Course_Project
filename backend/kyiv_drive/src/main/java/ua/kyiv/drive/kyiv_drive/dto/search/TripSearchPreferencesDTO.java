package ua.kyiv.drive.kyiv_drive.dto.search;

import lombok.Getter;
import lombok.Setter;
import com.fasterxml.jackson.annotation.JsonAnySetter;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import ua.kyiv.drive.kyiv_drive.model.search.SearchPriority;
import ua.kyiv.drive.kyiv_drive.model.search.SearchSort;

import java.util.List;
import java.util.UUID;

@Getter
@Setter
public class TripSearchPreferencesDTO {
    private SearchPriority priority;
    @Size(min = 1, message = "Priority order cannot be empty")
    private List<@NotNull(message = "Priority cannot be null") SearchPriority> order;
    private Boolean hasCustomOrder;
    private SearchSort sort;
    @Valid
    private TripSearchFiltersDTO filters;
    private boolean replace;
    private UUID anchorTripId;
    @Positive(message = "Restore result count must be positive")
    private Integer restoreResultCount;

    @JsonAnySetter
    public void rejectUnknownField(String name, Object value) {
        throw new IllegalArgumentException("Search addresses, schedule and desired times require a new search");
    }
}
