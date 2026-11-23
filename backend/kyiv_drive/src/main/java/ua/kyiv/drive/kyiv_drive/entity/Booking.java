package ua.kyiv.drive.kyiv_drive.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.ColumnDefault;
import org.hibernate.annotations.Generated;

import java.time.LocalDate;
import java.time.ZonedDateTime;
import java.util.UUID;

@Getter
@Setter
@Entity
@Table(name = "bookings")
public class Booking {

    @Id
    @Generated
    @ColumnDefault("uuidv7()")
    private UUID id;

    @Column(name = "trip_id", nullable = false)
    private UUID tripId;

    @Column(name = "passenger_id", nullable = false)
    private UUID passengerId;

    @Column(name = "start_stop_id")
    private UUID startStopId;

    @Column(name = "end_stop_id")
    private UUID endStopId;

    @Column(name = "seats", nullable = false)
    private Short seats = 1;

    @Column(name = "start_date", nullable = false)
    private LocalDate startDate;

    @Column(name = "is_regular", nullable = false)
    private Boolean isRegular;

    @Column(name = "monday")
    private Boolean monday;

    @Column(name = "tuesday")
    private Boolean tuesday;

    @Column(name = "wednesday")
    private Boolean wednesday;

    @Column(name = "thursday")
    private Boolean thursday;

    @Column(name = "friday")
    private Boolean friday;

    @Column(name = "saturday")
    private Boolean saturday;

    @Column(name = "sunday")
    private Boolean sunday;

    @Column(name = "created", nullable = false)
    private ZonedDateTime created;

    @Column(name = "status", nullable = false, length = 20)
    private String status;
}