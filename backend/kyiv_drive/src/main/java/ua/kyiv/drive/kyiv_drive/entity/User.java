package ua.kyiv.drive.kyiv_drive.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.ColumnDefault;
import org.hibernate.annotations.Generated;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

@Getter
@Setter
@Entity
@Table(name = "users")
public class User {

    @Id
    @Generated
    @ColumnDefault("uuidv7()")
    private UUID id;

    @Column(name = "email", nullable = false, unique = true)
    private String email;

    @Column(name = "name", length = 100, nullable = false)
    private String name;

    @Column(name = "password")
    private String password;

    @Column(name = "avatar_url", length = 2048)
    private String avatarUrl;

    @UpdateTimestamp
    @Column(name = "last_activity", nullable = false)
    private LocalDate lastActivity;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDate created;

    @Column(name = "is_active", nullable = false)
    private Boolean isActive = true;

    @Enumerated(EnumType.STRING)
    @ColumnDefault("'USER'")
    @Column(name = "role", length = 10, nullable = false)
    private UserRole role = UserRole.USER;

    @Column(name = "rating", nullable = false)
    private BigDecimal rating = BigDecimal.valueOf(0.0);

    @Column(name = "rating_count", nullable = false)
    private Integer ratingCount = 0;

    @Enumerated(EnumType.STRING)
    @ColumnDefault("'PASSENGER'")
    @Column(name = "current_mode", length = 10, nullable = false)
    private CurrentMode currentMode = CurrentMode.PASSENGER;

    @Column(name = "tutorial_completed", nullable = false)
    private Boolean tutorialCompleted = false;

    @Column(name = "bio")
    private String bio;
}
