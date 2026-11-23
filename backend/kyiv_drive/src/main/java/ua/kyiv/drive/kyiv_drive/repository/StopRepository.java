package ua.kyiv.drive.kyiv_drive.repository;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;
import ua.kyiv.drive.kyiv_drive.entity.Stop;

import java.util.*;

@Repository
public interface StopRepository extends JpaRepository<Stop, UUID> {
    Optional<Stop> findByOsmId(Long osmId);

    List<Stop> findAllByOsmIdIn(Collection<Long> osmIds);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT s FROM Stop s ORDER BY s.id")
    List<Stop> findAllForUpdate();

    @Lock(LockModeType.PESSIMISTIC_READ)
    @Query("SELECT s FROM Stop s WHERE s.id IN :ids ORDER BY s.id")
    List<Stop> findAllByIdForShare(@Param("ids") Collection<UUID> ids);

    @Modifying
    @Query("UPDATE Stop s SET s.isActive = false WHERE s.osmId NOT IN :activeOsmIds")
    void deactivateMissingStops(@Param("activeOsmIds") Set<Long> activeOsmIds);

    // Compute the right-side buffer once so the index scan can reuse it for each candidate.
    @Transactional(readOnly = true)
    @Query(value = """
        WITH route AS MATERIALIZED (
            SELECT ST_Transform(ST_GeomFromText(:wktPolyline, 4326), 32636) AS geom
        ),
        right_side_zone AS MATERIALIZED (
            SELECT ST_Buffer(geom, :bufferRadiusInMeters, 'side=right') AS area
            FROM route
        )
        SELECT
            s.id AS id,
            s.name AS name,
            ST_Y(s.location) AS lat,
            ST_X(s.location) AS lon,
            ST_LineLocatePoint(r.geom, ST_Transform(s.location, 32636)) AS routeFraction
        FROM stops s, route r, right_side_zone rsz
        WHERE s.is_active = true
          AND ST_Intersects(ST_Transform(s.location, 32636), rsz.area)
        ORDER BY routeFraction, s.id
        """, nativeQuery = true)
    List<StopFractionProjection> findStopsWithFraction(
            @Param("wktPolyline") String wktPolyline,
            @Param("bufferRadiusInMeters") double bufferRadiusInMeters
    );
}
