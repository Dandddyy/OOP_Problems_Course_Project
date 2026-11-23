package ua.kyiv.drive.kyiv_drive.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UuidGenerator;

import java.time.Instant;
import java.util.UUID;

@Getter
@Setter
@Entity
@Table(name = "user_sessions")
public class UserSession {

    @Id
    @GeneratedValue
    @UuidGenerator(style = UuidGenerator.Style.VERSION_7)
    @Column(nullable = false, updatable = false)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "installation_id", nullable = false, updatable = false)
    private UUID installationId;

    @Column(name = "device_name", length = 120, nullable = false)
    private String deviceName;

    @Enumerated(EnumType.STRING)
    @Column(name = "platform", length = 16, nullable = false, updatable = false)
    private DevicePlatform platform;

    @Column(name = "app_version", length = 32, nullable = false)
    private String appVersion;

    @Enumerated(EnumType.STRING)
    @Column(name = "current_mode", length = 10, nullable = false)
    private CurrentMode currentMode;

    @Column(name = "refresh_generation", nullable = false)
    private long refreshGeneration = 1;

    @Column(name = "current_refresh_hash", length = 64, nullable = false)
    private String currentRefreshHash;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "last_used_at", nullable = false)
    private Instant lastUsedAt;

    @Column(name = "idle_expires_at", nullable = false)
    private Instant idleExpiresAt;

    public boolean isExpiredAt(Instant instant) {
        return !idleExpiresAt.isAfter(instant);
    }
}
