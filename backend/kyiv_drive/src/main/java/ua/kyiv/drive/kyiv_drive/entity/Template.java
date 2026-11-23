package ua.kyiv.drive.kyiv_drive.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.ColumnDefault;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.Generated;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import org.locationtech.jts.geom.Point;

import java.time.ZonedDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Getter
@Setter
@Entity
@Table(name = "templates", uniqueConstraints = {
        @UniqueConstraint(
                name = "uk_templates_user_request_id",
                columnNames = {"user_id", "request_id"}
        )
})
public class Template {

    @Id
    @Generated
    @ColumnDefault("uuidv7()")
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "request_id", nullable = false)
    private UUID requestId;

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

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "waypoints", columnDefinition = "jsonb")
    private List<TripWaypoint> waypoints = new ArrayList<>();

    @Column(name = "route_polyline", nullable = false)
    private String routePolyline;

    @Column(name = "total_duration_seconds", nullable = false)
    private Integer totalDurationSeconds;

    @Column(name = "total_distance_meters", nullable = false)
    private Integer totalDistanceMeters;

    @Column(name = "is_driver", nullable = false)
    private Boolean isDriver = true;

    @Column(name = "stops_catalog_version", nullable = false)
    private Long stopsCatalogVersion = 0L;

    @OneToMany(mappedBy = "template", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("sequenceNumber ASC")
    private List<TemplateStop> templateStops = new ArrayList<>();

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private ZonedDateTime createdAt;

    public void addTemplateStop(TemplateStop stop) {
        templateStops.add(stop);
        stop.setTemplate(this);
    }
}
