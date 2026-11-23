package ua.kyiv.drive.kyiv_drive.repository.search;

import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;
import ua.kyiv.drive.kyiv_drive.model.search.SearchQuery;
import ua.kyiv.drive.kyiv_drive.model.search.SearchTripCandidate;

import java.time.Instant;
import java.time.LocalDate;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/** Search fragment composed into the trip repository. */
public interface TripSearchRepository {
    @Transactional(readOnly = true, isolation = Isolation.REPEATABLE_READ)
    List<SearchTripCandidate> findCandidates(SearchQuery query, UUID passengerId, Instant now);

    @Transactional(readOnly = true)
    Map<UUID, Instant> findCurrentVersions(Collection<UUID> ids, UUID passengerId, Instant now);

    @Transactional(readOnly = true)
    Map<UUID, Set<LocalDate>> findCancelledDates(Collection<UUID> ids);
}
