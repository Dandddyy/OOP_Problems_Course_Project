package ua.kyiv.drive.kyiv_drive.entity;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.ColumnDefault;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.Generated;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.annotations.UpdateTimestamp;
import org.hibernate.type.SqlTypes;
import org.locationtech.jts.geom.Point;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Getter
@Setter
@Entity
@Table(name = "trips", uniqueConstraints = {
        @UniqueConstraint(name = "uk_trips_driver_request_id", columnNames = {"driver_id", "request_id"})
})
public class Trip {

    @Id
    @Generated
    @ColumnDefault("uuidv7()")
    private UUID id;

    @Column(name = "driver_id", nullable = false)
    private UUID driverId;

    @Column(name = "request_id", nullable = false)
    private UUID requestId;

    @Column(name = "car_id", nullable = false)
    private UUID carId;

    @Column(name = "start_short_address", nullable = false, length = 255)
    private String startShortAddress;

    @Column(name = "start_subtitle", length = 255)
    private String startSubtitle;

    @Column(name = "end_short_address", nullable = false, length = 255)
    private String endShortAddress;

    @Column(name = "end_subtitle", length = 255)
    private String endSubtitle;

    @Column(name = "start_location", columnDefinition = "geography(Point, 4326)", nullable = false)
    private Point startLocation;

    @Column(name = "end_location", columnDefinition = "geography(Point, 4326)", nullable = false)
    private Point endLocation;

    @Column(name = "route_polyline", columnDefinition = "text", nullable = false)
    private String routePolyline;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "waypoints", columnDefinition = "jsonb")
    private List<TripWaypoint> waypoints = new ArrayList<>();

    @Column(name = "total_distance_meters", nullable = false)
    private Integer totalDistanceMeters;

    @Column(name = "total_duration_seconds", nullable = false)
    private Integer totalDurationSeconds;

    @Enumerated(EnumType.STRING)
    @Column(name = "schedule_type", nullable = false, length = 20)
    private TripScheduleType scheduleType;

    @JdbcTypeCode(SqlTypes.LOCAL_DATE)
    @Column(name = "first_departure_date", nullable = false)
    private LocalDate firstDepartureDate;

    @JdbcTypeCode(SqlTypes.LOCAL_TIME)
    @Column(name = "departure_local_time", nullable = false)
    private LocalTime departureLocalTime;

    @ColumnDefault("false")
    @Column(name = "monday", nullable = false)
    private boolean monday;

    @ColumnDefault("false")
    @Column(name = "tuesday", nullable = false)
    private boolean tuesday;

    @ColumnDefault("false")
    @Column(name = "wednesday", nullable = false)
    private boolean wednesday;

    @ColumnDefault("false")
    @Column(name = "thursday", nullable = false)
    private boolean thursday;

    @ColumnDefault("false")
    @Column(name = "friday", nullable = false)
    private boolean friday;

    @ColumnDefault("false")
    @Column(name = "saturday", nullable = false)
    private boolean saturday;

    @ColumnDefault("false")
    @Column(name = "sunday", nullable = false)
    private boolean sunday;

    @Enumerated(EnumType.STRING)
    @Column(name = "pricing_type", nullable = false, length = 20)
    private TripPricingType pricingType;

    @Column(name = "price_amount", nullable = false, precision = 10, scale = 2)
    private BigDecimal priceAmount;

    @ColumnDefault("true")
    @Column(name = "negotiation_allowed", nullable = false)
    private boolean negotiationAllowed = true;

    @Enumerated(EnumType.STRING)
    @ColumnDefault("'OPEN'")
    @Column(name = "recruitment_status", nullable = false, length = 20)
    private TripRecruitmentStatus recruitmentStatus = TripRecruitmentStatus.OPEN;

    @Enumerated(EnumType.STRING)
    @ColumnDefault("'ACTIVE'")
    @Column(name = "trip_status", nullable = false, length = 20)
    private TripStatus tripStatus = TripStatus.ACTIVE;

    @Column(name = "last_confirmed_at")
    private Instant lastConfirmedAt;

    @Column(name = "confirmation_expires_at")
    private Instant confirmationExpiresAt;

    @Column(name = "description", length = 255)
    private String description;

    @ColumnDefault("0")
    @Column(name = "stops_catalog_version", nullable = false)
    private Long stopsCatalogVersion = 0L;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @OneToMany(mappedBy = "trip", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("sequenceNumber ASC")
    private List<TripStop> tripStops = new ArrayList<>();

    public void addTripStop(TripStop stop) {
        tripStops.add(stop);
        stop.setTrip(this);
    }
}
