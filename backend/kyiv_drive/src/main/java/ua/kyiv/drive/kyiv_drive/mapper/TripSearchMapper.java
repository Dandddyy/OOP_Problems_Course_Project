package ua.kyiv.drive.kyiv_drive.mapper;

import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import ua.kyiv.drive.kyiv_drive.dto.search.TripSearchResultDTO;
import ua.kyiv.drive.kyiv_drive.dto.search.TripSearchResultDTO.PreferenceMatchDTO;
import ua.kyiv.drive.kyiv_drive.model.search.SearchQuery;
import ua.kyiv.drive.kyiv_drive.service.search.scoring.MatchedOccurrence;
import ua.kyiv.drive.kyiv_drive.service.search.scoring.ScoredTrip;

@Mapper(componentModel = "spring")
public interface TripSearchMapper {
    // TODO: Replace the temporary 1/1 placeholders with actual passenger capacity
    // and available seats once booking availability is implemented.
    @Mapping(target = "availableSeats", constant = "1")
    @Mapping(target = "totalSeats", constant = "1")
    @Mapping(target = ".", source = "scored.trip")
    @Mapping(target = "rideDurationSeconds",
            expression = "java(scored.dropoff().cumulativeDurationSeconds() - scored.pickup().cumulativeDurationSeconds())")
    @Mapping(target = "rideDistanceMeters",
            expression = "java(scored.dropoff().cumulativeDistanceMeters() - scored.pickup().cumulativeDistanceMeters())")
    @Mapping(target = "priceAmount", source = "scored.fare")
    @Mapping(target = "publishedRate", source = "scored.trip.priceAmount")
    @Mapping(target = "score", expression = "java(scored.displayScore())")
    @Mapping(target = "occurrences", source = "scored.occurrences")
    @Mapping(target = "matchedDateCount", expression = "java(scored.occurrences().size())")
    @Mapping(target = "requestedDateCount", expression = "java(query.anchorDates().size())")
    @Mapping(target = "preferenceMatch", ignore = true)
    TripSearchResultDTO toResult(ScoredTrip scored, SearchQuery query);

    @Mapping(target = "preferenceMatch", source = "preferenceMatch")
    TripSearchResultDTO withPreferenceMatch(TripSearchResultDTO result, PreferenceMatchDTO preferenceMatch);

    @Mapping(target = "requestedDate", expression = "java(occurrence.requestedDate())")
    @Mapping(target = "driverDepartureDate", source = "occurrence.occurrence.driverDepartureDate")
    TripSearchResultDTO.OccurrenceDTO toOccurrence(MatchedOccurrence occurrence);
}
