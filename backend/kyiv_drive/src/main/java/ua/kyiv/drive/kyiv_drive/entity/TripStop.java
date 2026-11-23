package ua.kyiv.drive.kyiv_drive.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.ColumnDefault;
import org.hibernate.annotations.Generated;
import org.locationtech.jts.geom.Point;

import java.util.UUID;

@Getter
@Setter
@Entity
@Table(name = "trip_stops", uniqueConstraints = {
        @UniqueConstraint(columnNames = {"trip_id", "sequence_number"})
})
public class TripStop {

    @Id
    @Generated
    @ColumnDefault("uuidv7()")
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "trip_id", nullable = false)
    private Trip trip;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "stop_id", nullable = false)
    private Stop stop;

    @Column(name = "sequence_number", nullable = false)
    private Short sequenceNumber;

    @Column(name = "cumulative_duration_seconds", nullable = false)
    private Integer cumulativeDurationSeconds;

    @Column(name = "cumulative_distance_meters", nullable = false)
    private Integer cumulativeDistanceMeters;

    @ColumnDefault("true")
    @Column(name = "is_enabled", nullable = false)
    private Boolean isEnabled = true;

    @Column(name = "stop_name_snapshot", columnDefinition = "text")
    private String stopNameSnapshot;

    @Column(name = "stop_location_snapshot", columnDefinition = "geography(Point, 4326)", nullable = false)
    private Point stopLocationSnapshot;
}
