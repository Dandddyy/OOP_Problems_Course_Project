package ua.kyiv.drive.kyiv_drive.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.ColumnDefault;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.Generated;

import java.time.Instant;
import java.util.UUID;

@Getter
@Setter
@Entity
@Table(name = "stop_import_changes")
public class StopImportChange {

    @Id
    @Generated
    @ColumnDefault("uuidv7()")
    private UUID id;

    @Column(name = "import_id", nullable = false)
    private UUID importId;

    @Column(name = "stop_id", nullable = false)
    private UUID stopId;

    @Column(name = "osm_id", nullable = false)
    private Long osmId;

    @Enumerated(EnumType.STRING)
    @Column(name = "change_type", length = 20, nullable = false)
    private StopImportChangeType changeType;

    @Column(name = "old_name", columnDefinition = "TEXT")
    private String oldName;

    @Column(name = "old_lat")
    private Double oldLat;

    @Column(name = "old_lon")
    private Double oldLon;

    @Column(name = "old_active")
    private Boolean oldActive;

    @Column(name = "new_name", columnDefinition = "TEXT")
    private String newName;

    @Column(name = "new_lat")
    private Double newLat;

    @Column(name = "new_lon")
    private Double newLon;

    @Column(name = "new_active")
    private Boolean newActive;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
}
