package ua.kyiv.drive.kyiv_drive.repository.search;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import ua.kyiv.drive.kyiv_drive.entity.TripPricingType;
import ua.kyiv.drive.kyiv_drive.entity.TripScheduleType;
import ua.kyiv.drive.kyiv_drive.model.search.SearchCoordinate;
import ua.kyiv.drive.kyiv_drive.model.search.SearchOccurrence;
import ua.kyiv.drive.kyiv_drive.model.search.SearchPoint;
import ua.kyiv.drive.kyiv_drive.model.search.SearchPolicy;
import ua.kyiv.drive.kyiv_drive.model.search.SearchQuery;
import ua.kyiv.drive.kyiv_drive.model.search.SearchTripCandidate;
import ua.kyiv.drive.kyiv_drive.validation.RoutePolicy;

import java.math.BigDecimal;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;
import java.util.stream.IntStream;

/** Compact spatial/schedule projections; no routing calls or entity graph loading. */
public class TripSearchRepositoryImpl implements TripSearchRepository {
    private static final int ID_BATCH_SIZE = 500;
    private static final String AVAILABLE = """
            t.trip_status = 'ACTIVE' AND t.recruitment_status = 'OPEN'
            AND t.driver_id <> :passengerId AND u.is_active = true AND c.is_deleted = false
            AND (t.schedule_type = 'ONE_TIME' OR t.confirmation_expires_at > CAST(:now AS timestamptz))
            AND (t.schedule_type = 'RECURRING'
                 OR ((t.first_departure_date + t.departure_local_time) AT TIME ZONE 'Europe/Kyiv')
                    + t.total_duration_seconds * INTERVAL '1 second' > CAST(:now AS timestamptz))
            """;

    private final NamedParameterJdbcTemplate jdbc;

    public TripSearchRepositoryImpl(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** Both reads observe one database snapshot, which is released before routing starts. */
    @Override
    public List<SearchTripCandidate> findCandidates(SearchQuery query, UUID passengerId, Instant now) {
        List<LocalDate> anchors = query.anchorDates();
        if (anchors.isEmpty()) {
            return List.of();
        }
        MapSqlParameterSource parameters = parameters(query, passengerId, now);
        String anchorValues = IntStream.range(0, anchors.size()).mapToObj(index -> {
            LocalDate anchor = anchors.get(index);
            parameters.addValue("date" + index, anchor.toString());
            parameters.addValue("departure" + index, query.departureTarget(anchor).toString());
            parameters.addValue("arrival" + index, query.arrivalTarget(anchor).toString());
            return "(CAST(:date" + index + " AS date), CAST(:departure" + index
                    + " AS timestamptz), CAST(:arrival" + index + " AS timestamptz))";
        }).collect(Collectors.joining(", "));
        Map<UUID, CandidateBuilder> candidates = new LinkedHashMap<>();
        jdbc.query(candidateSql(anchorValues), parameters, result -> {
            UUID tripId = result.getObject("trip_id", UUID.class);
            CandidateBuilder builder = candidates.get(tripId);
            if (builder == null) {
                builder = new CandidateBuilder(result);
                candidates.put(tripId, builder);
            }
            builder.occurrences.add(new SearchOccurrence(result.getObject("requested_date", LocalDate.class),
                    result.getObject("driver_date", LocalDate.class),
                    result.getTimestamp("departure_at").toInstant()));
        });
        for (List<UUID> ids : batches(candidates.keySet())) {
            MapSqlParameterSource pointsParameters = parameters(query, passengerId, now).addValue("tripIds", ids);
            jdbc.query("WITH points AS (" + pointsSql(true) + ") SELECT * FROM points ORDER BY trip_id, sequence_number",
                    pointsParameters, result -> {
                        CandidateBuilder builder = candidates.get(result.getObject("trip_id", UUID.class));
                        SearchPoint point = new SearchPoint(result.getObject("stop_id", UUID.class),
                                result.getInt("sequence_number"), result.getString("point_name"),
                                new SearchCoordinate(result.getDouble("longitude"), result.getDouble("latitude")),
                                result.getInt("duration_seconds"), result.getInt("distance_meters"));
                        if (result.getBoolean("pickup_candidate")) {
                            builder.pickups.add(point);
                        }
                        if (result.getBoolean("dropoff_candidate")) {
                            builder.dropoffs.add(point);
                        }
                    });
        }
        return candidates.values().stream().map(CandidateBuilder::build).toList();
    }

    @Override
    public Map<UUID, Instant> findCurrentVersions(Collection<UUID> ids, UUID passengerId, Instant now) {
        Map<UUID, Instant> versions = new HashMap<>();
        for (List<UUID> batch : batches(ids)) {
            MapSqlParameterSource parameters = new MapSqlParameterSource("tripIds", batch)
                    .addValue("passengerId", passengerId).addValue("now", now.toString());
            jdbc.query("""
                    SELECT t.id, t.updated_at FROM trips t
                    JOIN users u ON u.id = t.driver_id
                    JOIN cars c ON c.id = t.car_id
                    WHERE t.id IN (:tripIds) AND
                    """ + AVAILABLE, parameters, result -> {
                        versions.put(result.getObject("id", UUID.class),
                                result.getTimestamp("updated_at").toInstant());
                    });
        }
        return Map.copyOf(versions);
    }

    @Override
    public Map<UUID, Set<LocalDate>> findCancelledDates(Collection<UUID> ids) {
        Map<UUID, Set<LocalDate>> dates = new HashMap<>();
        for (List<UUID> batch : batches(ids)) {
            jdbc.query("SELECT trip_id, exception_date FROM trip_exceptions WHERE trip_id IN (:tripIds)",
                    new MapSqlParameterSource("tripIds", batch), result -> {
                        dates.computeIfAbsent(result.getObject("trip_id", UUID.class), ignored -> new HashSet<>())
                                .add(result.getObject("exception_date", LocalDate.class));
                    });
        }
        return dates.entrySet().stream().collect(Collectors.toUnmodifiableMap(Map.Entry::getKey,
                entry -> Set.copyOf(entry.getValue())));
    }

    private MapSqlParameterSource parameters(SearchQuery query, UUID passengerId, Instant now) {
        return new MapSqlParameterSource("originLon", query.origin().longitude())
                .addValue("originLat", query.origin().latitude())
                .addValue("destinationLon", query.destination().longitude())
                .addValue("destinationLat", query.destination().latitude())
                .addValue("radius", query.maxWalkMeters()).addValue("walkSeconds", query.maxWalkSeconds())
                .addValue("deviationSeconds", query.timeDeviationMinutes() * 60)
                .addValue("passengerId", passengerId).addValue("now", now.toString())
                .addValue("pickupNotBefore", now.plusSeconds(SearchPolicy.MIN_BOARDING_LEAD_SECONDS).toString())
                .addValue("minimumRideMeters", RoutePolicy.PASSENGER_MIN_DISTANCE_METERS)
                .addValue("recurringOnly", query.scheduleType() == TripScheduleType.RECURRING);
    }

    private String pointsSql(boolean restrictIds) {
        String tripIds = restrictIds ? " AND t.id IN (:tripIds)" : "";
        return pointBranch("t.start_location", "NULL::uuid", "0", "t.start_short_address", "0", "0",
                "trips t", tripIds)
                + " UNION ALL " + pointBranch("ts.stop_location_snapshot", "ts.stop_id", "ts.sequence_number",
                "COALESCE(ts.stop_name_snapshot, 'Stop')", "ts.cumulative_duration_seconds",
                "ts.cumulative_distance_meters", "trip_stops ts JOIN trips t ON t.id = ts.trip_id",
                " AND ts.is_enabled = true" + tripIds)
                + " UNION ALL " + pointBranch("t.end_location", "NULL::uuid", "32767", "t.end_short_address",
                "t.total_duration_seconds", "t.total_distance_meters", "trips t", tripIds);
    }

    private String pointBranch(String location, String stopId, String sequence, String name, String duration,
                               String distance, String from, String extraConditions) {
        String nearOrigin = "ST_DWithin(" + location
                + ", ST_SetSRID(ST_MakePoint(:originLon, :originLat), 4326)::geography, :radius)";
        String nearDestination = "ST_DWithin(" + location
                + ", ST_SetSRID(ST_MakePoint(:destinationLon, :destinationLat), 4326)::geography, :radius)";
        return "SELECT t.id AS trip_id, " + stopId + " AS stop_id, " + sequence + " AS sequence_number, "
                + name + " AS point_name, ST_X(" + location + "::geometry) AS longitude, ST_Y(" + location
                + "::geometry) AS latitude, " + duration + " AS duration_seconds, " + distance
                + " AS distance_meters, " + nearOrigin + " AS pickup_candidate, " + nearDestination
                + " AS dropoff_candidate FROM " + from
                + " WHERE t.trip_status = 'ACTIVE' AND t.recruitment_status = 'OPEN'" + extraConditions
                + " AND (" + nearOrigin + " OR " + nearDestination + ")";
    }

    private String candidateSql(String anchorValues) {
        return "WITH anchors(requested_date, departure_target, arrival_target) AS (VALUES " + anchorValues
                + "), points AS MATERIALIZED (" + pointsSql(false) + "), eligible_trips AS MATERIALIZED ("
                + """
                SELECT t.id, t.driver_id, t.car_id, t.pricing_type, t.price_amount,
                    t.negotiation_allowed, t.updated_at, t.schedule_type, t.first_departure_date,
                    t.departure_local_time, t.monday, t.tuesday, t.wednesday, t.thursday,
                    t.friday, t.saturday, t.sunday,
                    u.name AS driver_name, u.avatar_url AS driver_avatar_url,
                    u.rating AS driver_rating, u.rating_count AS driver_rating_count,
                    cb.name || ' ' || cm.name AS car_label
                FROM trips t JOIN users u ON u.id = t.driver_id JOIN cars c ON c.id = t.car_id
                JOIN car_models cm ON cm.id = c.model_id JOIN car_brands cb ON cb.id = cm.brand_id
                WHERE
                """ + AVAILABLE + """
                AND (NOT :recurringOnly OR t.schedule_type = 'RECURRING')
                AND EXISTS (SELECT 1 FROM points p WHERE p.trip_id = t.id AND p.pickup_candidate
                    AND EXISTS (SELECT 1 FROM points d WHERE d.trip_id = t.id AND d.dropoff_candidate
                        AND d.sequence_number > p.sequence_number
                        AND d.distance_meters::bigint - p.distance_meters >= :minimumRideMeters))
                ), start_windows AS (
                    SELECT p.trip_id, a.requested_date,
                        ((a.departure_target - (:deviationSeconds + p.duration_seconds::bigint) * INTERVAL '1 second')
                            AT TIME ZONE 'Europe/Kyiv')::date AS first_date,
                        ((a.departure_target + (:deviationSeconds + :walkSeconds - p.duration_seconds::bigint)
                            * INTERVAL '1 second') AT TIME ZONE 'Europe/Kyiv')::date AS last_date
                    FROM points p JOIN eligible_trips t ON t.id = p.trip_id CROSS JOIN anchors a
                    WHERE p.pickup_candidate
                    UNION ALL
                    SELECT p.trip_id, a.requested_date,
                        ((a.arrival_target - (:deviationSeconds + :walkSeconds + p.duration_seconds::bigint)
                            * INTERVAL '1 second') AT TIME ZONE 'Europe/Kyiv')::date,
                        ((a.arrival_target + (:deviationSeconds - p.duration_seconds::bigint) * INTERVAL '1 second')
                            AT TIME ZONE 'Europe/Kyiv')::date
                    FROM points p JOIN eligible_trips t ON t.id = p.trip_id CROSS JOIN anchors a
                    WHERE p.dropoff_candidate
                ), possible_dates AS (
                    SELECT DISTINCT w.trip_id, w.requested_date, day::date AS driver_date
                    FROM start_windows w CROSS JOIN LATERAL generate_series(
                        w.first_date::timestamp, w.last_date::timestamp, INTERVAL '1 day') day
                ), occurrences AS (
                    SELECT t.*, d.requested_date, d.driver_date,
                        ((d.driver_date + t.departure_local_time) AT TIME ZONE 'Europe/Kyiv') AS departure_at
                    FROM possible_dates d JOIN eligible_trips t ON t.id = d.trip_id
                    WHERE (t.schedule_type = 'ONE_TIME' AND d.driver_date = t.first_departure_date)
                        OR (t.schedule_type = 'RECURRING' AND d.driver_date >= t.first_departure_date
                            AND CASE EXTRACT(ISODOW FROM d.driver_date)::int
                                WHEN 1 THEN t.monday WHEN 2 THEN t.tuesday WHEN 3 THEN t.wednesday
                                WHEN 4 THEN t.thursday WHEN 5 THEN t.friday WHEN 6 THEN t.saturday
                                WHEN 7 THEN t.sunday END)
                )
                SELECT o.id AS trip_id, o.driver_id, o.driver_name,
                    o.driver_avatar_url, o.driver_rating, o.driver_rating_count, o.car_id, o.car_label,
                    o.pricing_type, o.price_amount, o.negotiation_allowed, o.updated_at,
                    o.requested_date, o.driver_date, o.departure_at
                FROM occurrences o JOIN anchors a ON a.requested_date = o.requested_date
                WHERE (o.departure_at AT TIME ZONE 'Europe/Kyiv') = o.driver_date + o.departure_local_time
                  AND NOT EXISTS (SELECT 1 FROM trip_exceptions e
                    WHERE e.trip_id = o.id AND e.exception_date = o.driver_date)
                  AND EXISTS (SELECT 1 FROM points p
                    WHERE p.trip_id = o.id AND p.pickup_candidate
                      AND o.departure_at + p.duration_seconds * INTERVAL '1 second' >= CAST(:pickupNotBefore AS timestamptz)
                      AND EXISTS (SELECT 1 FROM points d
                        WHERE d.trip_id = o.id AND d.dropoff_candidate AND d.sequence_number > p.sequence_number
                          AND d.distance_meters::bigint - p.distance_meters >= :minimumRideMeters
                          AND ((o.departure_at + p.duration_seconds * INTERVAL '1 second'
                                BETWEEN a.departure_target - :deviationSeconds * INTERVAL '1 second'
                                    AND a.departure_target + (:deviationSeconds + :walkSeconds) * INTERVAL '1 second')
                            OR (o.departure_at + d.duration_seconds * INTERVAL '1 second'
                                BETWEEN a.arrival_target - (:deviationSeconds + :walkSeconds) * INTERVAL '1 second'
                                    AND a.arrival_target + :deviationSeconds * INTERVAL '1 second'))))
                ORDER BY o.id, o.requested_date, o.departure_at
                """;
    }

    private static List<List<UUID>> batches(Collection<UUID> ids) {
        List<UUID> values = List.copyOf(ids);
        List<List<UUID>> batches = new ArrayList<>();
        for (int offset = 0; offset < values.size(); offset += ID_BATCH_SIZE) {
            batches.add(values.subList(offset, Math.min(values.size(), offset + ID_BATCH_SIZE)));
        }
        return batches;
    }

    private static final class CandidateBuilder {
        private final UUID tripId;
        private final UUID driverId;
        private final String driverName;
        private final String driverAvatarUrl;
        private final BigDecimal driverRating;
        private final int driverRatingCount;
        private final UUID carId;
        private final String carLabel;
        private final TripPricingType pricingType;
        private final BigDecimal priceAmount;
        private final boolean negotiationAllowed;
        private final Instant updatedAt;
        private final List<SearchPoint> pickups = new ArrayList<>();
        private final List<SearchPoint> dropoffs = new ArrayList<>();
        private final List<SearchOccurrence> occurrences = new ArrayList<>();

        private CandidateBuilder(ResultSet result) throws SQLException {
            tripId = result.getObject("trip_id", UUID.class);
            driverId = result.getObject("driver_id", UUID.class);
            driverName = result.getString("driver_name");
            String avatarUrl = result.getString("driver_avatar_url");
            driverAvatarUrl = avatarUrl == null || avatarUrl.isBlank() ? null : avatarUrl.strip();
            driverRating = result.getBigDecimal("driver_rating");
            driverRatingCount = result.getInt("driver_rating_count");
            carId = result.getObject("car_id", UUID.class);
            carLabel = result.getString("car_label");
            pricingType = TripPricingType.valueOf(result.getString("pricing_type"));
            priceAmount = result.getBigDecimal("price_amount");
            negotiationAllowed = result.getBoolean("negotiation_allowed");
            updatedAt = result.getTimestamp("updated_at").toInstant();
        }

        private SearchTripCandidate build() {
            return new SearchTripCandidate(tripId, driverId, driverName, driverAvatarUrl, driverRating,
                    driverRatingCount, carId, carLabel, pricingType,
                    priceAmount, negotiationAllowed, updatedAt, List.copyOf(pickups), List.copyOf(dropoffs),
                    List.copyOf(occurrences));
        }
    }
}
