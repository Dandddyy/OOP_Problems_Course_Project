package ua.kyiv.drive.kyiv_drive.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.ColumnDefault;
import org.hibernate.annotations.Generated;

import java.time.ZonedDateTime;
import java.util.UUID;

@Getter
@Setter
@Entity
@Table(name = "chats", uniqueConstraints = {
        @UniqueConstraint(columnNames = {"trip_id", "driver_id", "passenger_id"})
})
public class Chat {

    @Id
    @Generated
    @ColumnDefault("uuidv7()")
    private UUID id;

    @Column(name = "trip_id", nullable = false)
    private UUID tripId;

    @Column(name = "driver_id", nullable = false)
    private UUID driverId;

    @Column(name = "passenger_id", nullable = false)
    private UUID passengerId;

    @Column(name = "last_message_content")
    private String lastMessageContent;

    @Column(name = "last_message_at")
    private ZonedDateTime lastMessageAt;

    @Column(name = "created_at", nullable = false)
    private ZonedDateTime createdAt;
}