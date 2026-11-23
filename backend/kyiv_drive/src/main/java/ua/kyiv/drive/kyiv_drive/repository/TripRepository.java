package ua.kyiv.drive.kyiv_drive.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import ua.kyiv.drive.kyiv_drive.entity.Trip;
import ua.kyiv.drive.kyiv_drive.entity.TripStatus;
import ua.kyiv.drive.kyiv_drive.repository.search.TripSearchRepository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface TripRepository extends JpaRepository<Trip, UUID>, TripSearchRepository {
    boolean existsByCarId(UUID carId);

    @Query("SELECT DISTINCT t FROM Trip t LEFT JOIN FETCH t.tripStops ts " +
            "LEFT JOIN FETCH ts.stop WHERE t.driverId = :driverId AND t.requestId = :requestId")
    Optional<Trip> findByDriverIdAndRequestIdWithStops(
            @Param("driverId") UUID driverId, @Param("requestId") UUID requestId
    );

    List<Trip> findAllByDriverIdAndTripStatus(UUID driverId, TripStatus status);
    long countByDriverIdAndTripStatus(UUID driverId, TripStatus status);

    @Query(value = """
            SELECT count(*) FROM trips
            WHERE driver_id = :driverId AND trip_status = 'ACTIVE'
              AND (schedule_type = 'RECURRING'
                   OR ((first_departure_date + departure_local_time) AT TIME ZONE 'Europe/Kyiv')
                      + total_duration_seconds * INTERVAL '1 second' > :now)
            """, nativeQuery = true)
    long countActiveForPublication(@Param("driverId") UUID driverId, @Param("now") Instant now);

    @Modifying(flushAutomatically = true)
    @Query(value = """
            UPDATE trips SET trip_status = 'EXPIRED', updated_at = :now
            WHERE driver_id = :driverId AND trip_status = 'ACTIVE' AND schedule_type = 'ONE_TIME'
              AND ((first_departure_date + departure_local_time) AT TIME ZONE 'Europe/Kyiv')
                  + total_duration_seconds * INTERVAL '1 second' <= :now
            """, nativeQuery = true)
    int expireCompletedOneTimeTrips(@Param("driverId") UUID driverId, @Param("now") Instant now);
}
