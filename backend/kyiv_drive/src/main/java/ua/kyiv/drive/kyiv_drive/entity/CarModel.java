package ua.kyiv.drive.kyiv_drive.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.ColumnDefault;
import org.hibernate.annotations.Generated;
import ua.kyiv.drive.kyiv_drive.validation.InputValidation;

import java.util.UUID;

@Getter
@Setter
@Entity
@Table(name = "car_models", uniqueConstraints = {
        @UniqueConstraint(columnNames = {"brand_id", "name"})
})
public class CarModel {

    @Id
    @Generated
    @ColumnDefault("uuidv7()")
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "brand_id", nullable = false)
    private CarBrand brand;

    @Column(
            name = "name",
            length = InputValidation.MAX_CAR_CATALOG_NAME_LENGTH,
            nullable = false
    )
    private String name;

    @Column(name = "is_verified", nullable = false)
    private boolean isVerified = false;
}
