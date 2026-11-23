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
@Table(name = "cars")
public class Car {

    @Id
    @Generated
    @ColumnDefault("uuidv7()")
    private UUID id;

    @Column(name = "owner_id", nullable = false)
    private UUID ownerId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "model_id", nullable = false)
    private CarModel model;

    @Enumerated(EnumType.STRING)
    @Column(name = "color", nullable = false, length = 30)
    private CarColor color;

    @Column(name = "plate_number", length = 12, nullable = false)
    private String plateNumber;

    @Column(name = "is_deleted", nullable = false)
    private boolean isDeleted = false;

    @Column(name = "passenger_capacity", nullable = false)
    private Short passengerCapacity;
}