package ua.kyiv.drive.kyiv_drive.model.search;

import java.util.List;

public record SearchPreferences(SearchPriority priority, List<SearchPriority> order, boolean hasCustomOrder) {
    public static final List<SearchPriority> DEFAULT_ORDER = List.of(SearchPriority.DEPARTURE,
            SearchPriority.ARRIVAL, SearchPriority.WALKING, SearchPriority.PRICE, SearchPriority.WEEKDAYS);
}
