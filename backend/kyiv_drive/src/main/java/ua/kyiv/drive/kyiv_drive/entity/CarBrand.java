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
@Table(name = "car_brands")
public class CarBrand {

    @Id
    @Generated
    @ColumnDefault("uuidv7()")
    private UUID id;

    @Column(
            name = "name",
            length = InputValidation.MAX_CAR_CATALOG_NAME_LENGTH,
            nullable = false,
            unique = true
    )
    private String name;
}
