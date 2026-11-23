package ua.kyiv.drive.kyiv_drive.repository;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import ua.kyiv.drive.kyiv_drive.entity.CurrentMode;
import ua.kyiv.drive.kyiv_drive.entity.UserSession;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface UserSessionRepository extends JpaRepository<UserSession, UUID> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT s FROM UserSession s JOIN FETCH s.user WHERE s.id = :id")
    Optional<UserSession> findByIdForUpdate(@Param("id") UUID id);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("""
            SELECT s
            FROM UserSession s
            WHERE s.user.id = :userId
              AND s.installationId = :installationId
            """)
    Optional<UserSession> findByInstallationForUpdate(
            @Param("userId") UUID userId,
            @Param("installationId") UUID installationId
    );

    List<UserSession> findAllByUser_IdOrderByLastUsedAtAsc(UUID userId);

    @Query("""
            SELECT s
            FROM UserSession s
            WHERE s.user.id = :userId
              AND s.user.isActive = true
              AND s.idleExpiresAt > :now
            ORDER BY s.lastUsedAt DESC
            """)
    List<UserSession> findAllActiveByUserId(
            @Param("userId") UUID userId,
            @Param("now") Instant now
    );

    Optional<UserSession> findByIdAndUser_Id(UUID id, UUID userId);

    @Query("""
            SELECT s.currentMode
            FROM UserSession s
            WHERE s.id = :sessionId
              AND s.user.id = :userId
              AND s.user.isActive = true
              AND s.idleExpiresAt > :now
            """)
    Optional<CurrentMode> findActiveCurrentMode(
            @Param("sessionId") UUID sessionId,
            @Param("userId") UUID userId,
            @Param("now") Instant now
    );

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("DELETE FROM UserSession s WHERE s.user.id = :userId")
    int deleteAllByUserId(@Param("userId") UUID userId);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            DELETE FROM UserSession s
            WHERE s.user.id = :userId
              AND s.id <> :currentSessionId
            """)
    int deleteAllExceptSession(
            @Param("userId") UUID userId,
            @Param("currentSessionId") UUID currentSessionId
    );

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            DELETE FROM UserSession s
            WHERE s.id = :sessionId
              AND s.user.id = :userId
            """)
    int deleteByIdAndUserId(
            @Param("sessionId") UUID sessionId,
            @Param("userId") UUID userId
    );

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            DELETE FROM UserSession s
            WHERE s.idleExpiresAt <= :now
            """)
    int deleteExpiredSessions(@Param("now") Instant now);
}
