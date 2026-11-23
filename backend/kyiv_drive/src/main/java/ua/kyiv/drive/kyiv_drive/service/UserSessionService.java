package ua.kyiv.drive.kyiv_drive.service;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import ua.kyiv.drive.kyiv_drive.auth.JwtTokenService;
import ua.kyiv.drive.kyiv_drive.auth.RefreshTokenClaims;
import ua.kyiv.drive.kyiv_drive.auth.TokenHash;
import ua.kyiv.drive.kyiv_drive.config.SessionProperties;
import ua.kyiv.drive.kyiv_drive.dto.user.AccessTokenResponseDTO;
import ua.kyiv.drive.kyiv_drive.dto.user.AuthResponseDTO;
import ua.kyiv.drive.kyiv_drive.dto.user.DeviceContextDTO;
import ua.kyiv.drive.kyiv_drive.dto.user.SessionContextDTO;
import ua.kyiv.drive.kyiv_drive.dto.user.UserSessionResponseDTO;
import ua.kyiv.drive.kyiv_drive.entity.CurrentMode;
import ua.kyiv.drive.kyiv_drive.entity.User;
import ua.kyiv.drive.kyiv_drive.entity.UserSession;
import ua.kyiv.drive.kyiv_drive.exception.SessionNotActiveException;
import ua.kyiv.drive.kyiv_drive.mapper.CurrentUserMapper;
import ua.kyiv.drive.kyiv_drive.repository.UserRepository;
import ua.kyiv.drive.kyiv_drive.repository.UserSessionRepository;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class UserSessionService {

    private static final String PENDING_REFRESH_HASH = "0".repeat(64);

    private final UserSessionRepository sessionRepository;
    private final UserRepository userRepository;
    private final JwtTokenService jwtTokenService;
    private final SessionProperties properties;
    private final Clock clock;
    private final CurrentUserMapper currentUserMapper;

    @Transactional
    public AuthResponseDTO startSession(User user, DeviceContextDTO device) {
        User lockedUser = userRepository.findByIdForUpdate(user.getId())
                .orElseThrow(() -> new IllegalArgumentException("User not found"));
        Instant now = clock.instant().truncatedTo(ChronoUnit.SECONDS);

        sessionRepository.findByInstallationForUpdate(lockedUser.getId(), device.getInstallationId())
                .ifPresent(sessionRepository::delete);
        sessionRepository.flush();

        List<UserSession> sessions = sessionRepository.findAllByUser_IdOrderByLastUsedAtAsc(lockedUser.getId());
        List<UserSession> activeSessions = sessions.stream()
                .filter(session -> !session.isExpiredAt(now))
                .toList();
        sessions.stream()
                .filter(session -> session.isExpiredAt(now))
                .forEach(sessionRepository::delete);

        int sessionsToEvict = activeSessions.size() - properties.getMaxActiveSessions() + 1;
        for (int i = 0; i < sessionsToEvict; i++) {
            sessionRepository.delete(activeSessions.get(i));
        }
        sessionRepository.flush();

        Instant idleExpiresAt = now.plus(properties.getRefreshIdleTtl());
        UserSession session = new UserSession();
        session.setUser(lockedUser);
        session.setInstallationId(device.getInstallationId());
        session.setDeviceName(device.getDeviceName());
        session.setPlatform(device.getPlatform());
        session.setAppVersion(device.getAppVersion());
        session.setCurrentMode(lockedUser.getCurrentMode());
        session.setRefreshGeneration(1);
        session.setCurrentRefreshHash(PENDING_REFRESH_HASH);
        session.setLastUsedAt(now);
        session.setIdleExpiresAt(idleExpiresAt);
        sessionRepository.saveAndFlush(session);

        String refreshToken = jwtTokenService.generateRefreshToken(
                new RefreshTokenClaims(lockedUser.getId(), session.getId(), 1, idleExpiresAt)
        );
        session.setCurrentRefreshHash(TokenHash.sha256(refreshToken));

        return authResponse(lockedUser, session, refreshToken);
    }

    @Transactional
    public void deleteCurrentSession(UUID userId, UUID sessionId) {
        if (sessionId == null) {
            return;
        }

        sessionRepository.findByIdForUpdate(sessionId)
                .filter(session -> session.getUser().getId().equals(userId))
                .ifPresent(sessionRepository::delete);
    }

    @Transactional
    public void deleteAllSessions(UUID userId) {
        sessionRepository.deleteAllByUserId(userId);
    }

    @Transactional(readOnly = true)
    public List<UserSessionResponseDTO> getSessions(UUID userId, UUID currentSessionId) {
        if (currentSessionId == null) {
            throw new SessionNotActiveException();
        }

        List<UserSession> sessions = sessionRepository.findAllActiveByUserId(userId, clock.instant());
        boolean currentSessionIsActive = sessions.stream()
                .anyMatch(session -> session.getId().equals(currentSessionId));
        if (!currentSessionIsActive) {
            throw new SessionNotActiveException();
        }

        return sessions.stream()
                .map(session -> sessionResponse(session, currentSessionId))
                .toList();
    }

    @Transactional
    public void deleteSession(UUID userId, UUID currentSessionId, UUID sessionId) {
        requireActiveAuthenticatedSession(userId, currentSessionId);
        sessionRepository.deleteByIdAndUserId(sessionId, userId);
    }

    @Transactional
    public void deleteOtherSessions(UUID userId, UUID currentSessionId) {
        requireActiveAuthenticatedSession(userId, currentSessionId);
        sessionRepository.deleteAllExceptSession(userId, currentSessionId);
    }

    @Transactional
    public AccessTokenResponseDTO switchMode(UUID userId, UUID sessionId, CurrentMode targetMode) {
        if (sessionId == null) {
            throw new SessionNotActiveException();
        }

        User lockedUser = userRepository.findByIdForUpdate(userId)
                .filter(User::getIsActive)
                .orElseThrow(SessionNotActiveException::new);
        UserSession session = sessionRepository.findByIdForUpdate(sessionId)
                .orElseThrow(SessionNotActiveException::new);
        Instant now = clock.instant();

        if (!session.getUser().getId().equals(userId)) {
            throw new SessionNotActiveException();
        }
        if (session.isExpiredAt(now)) {
            sessionRepository.delete(session);
            throw new SessionNotActiveException();
        }
        if (session.getCurrentMode() == targetMode) {
            throw new IllegalArgumentException("User is already in " + targetMode + " mode");
        }

        session.setCurrentMode(targetMode);
        session.setLastUsedAt(now);
        lockedUser.setCurrentMode(targetMode);
        JwtTokenService.IssuedAccessToken accessToken = accessToken(lockedUser, session);
        return new AccessTokenResponseDTO(
                "Bearer",
                accessToken.token(),
                accessToken.expiresAt(),
                sessionContext(session)
        );
    }

    AuthResponseDTO authResponse(User user, UserSession session, String refreshToken) {
        JwtTokenService.IssuedAccessToken accessToken = accessToken(user, session);
        return new AuthResponseDTO(
                "Bearer",
                accessToken.token(),
                accessToken.expiresAt(),
                refreshToken,
                session.getIdleExpiresAt(),
                sessionContext(session),
                currentUserMapper.toDTO(user)
        );
    }

    private JwtTokenService.IssuedAccessToken accessToken(User user, UserSession session) {
        return jwtTokenService.issueAccessToken(
                user.getId(),
                session.getId(),
                user.getRole(),
                session.getCurrentMode()
        );
    }

    private SessionContextDTO sessionContext(UserSession session) {
        return new SessionContextDTO(session.getId(), session.getCurrentMode());
    }

    private UserSessionResponseDTO sessionResponse(UserSession session, UUID currentSessionId) {
        return new UserSessionResponseDTO(
                session.getId(),
                session.getDeviceName(),
                session.getPlatform(),
                session.getAppVersion(),
                session.getCurrentMode(),
                session.getCreatedAt(),
                session.getLastUsedAt(),
                session.getIdleExpiresAt(),
                session.getId().equals(currentSessionId)
        );
    }

    private void requireActiveAuthenticatedSession(UUID userId, UUID sessionId) {
        if (sessionId == null) {
            throw new SessionNotActiveException();
        }

        User user = userRepository.findByIdForUpdate(userId)
                .filter(User::getIsActive)
                .orElseThrow(SessionNotActiveException::new);
        UserSession session = sessionRepository.findByIdAndUser_Id(sessionId, user.getId())
                .orElseThrow(SessionNotActiveException::new);
        if (session.isExpiredAt(clock.instant())) {
            sessionRepository.delete(session);
            throw new SessionNotActiveException();
        }
    }

}
