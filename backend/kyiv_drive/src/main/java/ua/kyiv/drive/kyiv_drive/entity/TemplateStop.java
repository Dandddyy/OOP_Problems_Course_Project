package ua.kyiv.drive.kyiv_drive.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.ColumnDefault;
import org.hibernate.annotations.Generated;

import java.util.UUID;

@Getter
@Setter
@Entity
@Table(name = "template_stops", uniqueConstraints = {
        @UniqueConstraint(columnNames = {"template_id", "sequence_number"})
})
public class TemplateStop {

    @Id
    @Generated
    @ColumnDefault("uuidv7()")
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "template_id", nullable = false)
    private Template template;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "stop_id", nullable = false)
    private Stop stop;

    @Column(name = "sequence_number", nullable = false)
    private Short sequenceNumber;

    @Column(name = "cumulative_duration_seconds", nullable = false)
    private Integer cumulativeDurationSeconds;

    @Column(name = "cumulative_distance_meters", nullable = false)
    private Integer cumulativeDistanceMeters;

    @Column(name = "is_enabled", nullable = false)
    private Boolean isEnabled = true;
}
