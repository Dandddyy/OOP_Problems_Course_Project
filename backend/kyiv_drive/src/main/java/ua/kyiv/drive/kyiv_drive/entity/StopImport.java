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
@Table(name = "stop_imports")
public class StopImport {

    @Id
    @Generated
    @ColumnDefault("uuidv7()")
    private UUID id;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", length = 20, nullable = false)
    private StopImportStatus status;

    @Column(name = "catalog_version", unique = true)
    private Long catalogVersion;

    @Column(name = "changes_recorded", nullable = false)
    private boolean changesRecorded;

    @Column(name = "original_filename")
    private String originalFilename;

    @Column(name = "file_hash", length = 64, nullable = false)
    private String fileHash;

    @Column(name = "catalog_hash", length = 64, nullable = false)
    private String catalogHash;

    @Column(name = "total_features", nullable = false)
    private int totalFeatures;

    @Column(name = "accepted_stops", nullable = false)
    private int acceptedStops;

    @Column(name = "out_of_bounds_features", nullable = false)
    private int outOfBoundsFeatures;

    @Column(name = "current_active_stops", nullable = false)
    private int currentActiveStops;

    @Column(name = "new_stops", nullable = false)
    private int newStops;

    @Column(name = "existing_stops", nullable = false)
    private int existingStops;

    @Column(name = "changed_stops", nullable = false)
    private int changedStops;

    @Column(name = "unchanged_stops", nullable = false)
    private int unchangedStops;

    @Column(name = "renamed_stops", nullable = false)
    private int renamedStops;

    @Column(name = "moved_stops", nullable = false)
    private int movedStops;

    @Column(name = "reactivated_stops", nullable = false)
    private int reactivatedStops;

    @Column(name = "deactivated_stops", nullable = false)
    private int deactivatedStops;

    @Column(name = "deactivation_percentage", nullable = false)
    private double deactivationPercentage;

    @Column(name = "confirmation_required", nullable = false)
    private boolean confirmationRequired;

    @Column(name = "confirmation_provided", nullable = false)
    private boolean confirmationProvided;

    @Column(name = "previewed_by_user_id", nullable = false)
    private UUID previewedByUserId;

    @Column(name = "previewed_by_email", length = 320, nullable = false)
    private String previewedByEmail;

    @CreationTimestamp
    @Column(name = "previewed_at", nullable = false, updatable = false)
    private Instant previewedAt;

    @Column(name = "applied_by_user_id")
    private UUID appliedByUserId;

    @Column(name = "applied_by_email", length = 320)
    private String appliedByEmail;

    @Column(name = "applied_at")
    private Instant appliedAt;
}
