package ua.kyiv.drive.kyiv_drive.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.ColumnDefault;
import org.hibernate.annotations.Generated;
import org.locationtech.jts.geom.Point;
import java.util.UUID;

@Getter
@Setter
@Entity
@Table(name = "stops")
public class Stop {

    @Id
    @Generated
    @ColumnDefault("uuidv7()")
    private UUID id;

    @Column(name = "name")
    private String name;

    @Column(name = "location", columnDefinition = "geometry(Point, 4326)", nullable = false)
    private Point location;

    @Column(name = "osm_id", unique = true, nullable = false)
    private Long osmId;

    @Column(name = "is_active", nullable = false)
    private Boolean isActive = true;
}