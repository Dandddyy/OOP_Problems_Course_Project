package ua.kyiv.drive.kyiv_drive.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import ua.kyiv.drive.kyiv_drive.auth.JwtTokenService;
import ua.kyiv.drive.kyiv_drive.auth.RefreshTokenClaims;
import ua.kyiv.drive.kyiv_drive.auth.TokenHash;
import ua.kyiv.drive.kyiv_drive.config.SessionProperties;
import ua.kyiv.drive.kyiv_drive.dto.user.DeviceContextDTO;
import ua.kyiv.drive.kyiv_drive.entity.UserSession;
import ua.kyiv.drive.kyiv_drive.repository.UserSessionRepository;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;

@Slf4j
@Service
@RequiredArgsConstructor
public class RefreshRotationTransaction {

    private final UserSessionRepository sessionRepository;
    private final JwtTokenService jwtTokenService;
    private final UserSessionService userSessionService;
    private final SessionProperties properties;
    private final Clock clock;

    @Transactional
    public RefreshRotationResult rotate(
            RefreshTokenClaims claims,
            String rawToken,
            DeviceContextDTO device
    ) {
        UserSession session = sessionRepository.findByIdForUpdate(claims.sessionId()).orElse(null);
        if (session == null) {
            return RefreshRotationResult.rejected();
        }

        Instant now = clock.instant().truncatedTo(ChronoUnit.SECONDS);
        if (session.isExpiredAt(now)) {
            sessionRepository.delete(session);
            return RefreshRotationResult.rejected();
        }
        if (!session.getUser().getIsActive()) {
            sessionRepository.delete(session);
            return RefreshRotationResult.rejected();
        }
        if (!session.getUser().getId().equals(claims.userId())) {
            log.warn("Refresh token subject does not own session {}", claims.sessionId());
            return RefreshRotationResult.rejected();
        }

        long currentGeneration = session.getRefreshGeneration();
        if (claims.generation() < currentGeneration) {
            sessionRepository.delete(session);
            return RefreshRotationResult.rejected();
        }
        if (claims.generation() > currentGeneration) {
            log.warn("Refresh token generation is ahead of session {}", claims.sessionId());
            return RefreshRotationResult.rejected();
        }

        boolean hashMatches = TokenHash.matches(rawToken, session.getCurrentRefreshHash());
        if (!hashMatches) {
            sessionRepository.delete(session);
            return RefreshRotationResult.rejected();
        }
        if (!session.getInstallationId().equals(device.getInstallationId())
                || session.getPlatform() != device.getPlatform()) {
            return RefreshRotationResult.rejected();
        }

        final long nextGeneration;
        try {
            nextGeneration = Math.incrementExact(currentGeneration);
        } catch (ArithmeticException e) {
            sessionRepository.delete(session);
            return RefreshRotationResult.rejected();
        }

        Instant idleExpiresAt = now.plus(properties.getRefreshIdleTtl());
        String nextRefreshToken = jwtTokenService.generateRefreshToken(
                new RefreshTokenClaims(
                        session.getUser().getId(),
                        session.getId(),
                        nextGeneration,
                        idleExpiresAt
                )
        );

        session.setRefreshGeneration(nextGeneration);
        session.setCurrentRefreshHash(TokenHash.sha256(nextRefreshToken));
        session.setDeviceName(device.getDeviceName());
        session.setAppVersion(device.getAppVersion());
        session.setLastUsedAt(now);
        session.setIdleExpiresAt(idleExpiresAt);

        return RefreshRotationResult.accepted(
                userSessionService.authResponse(session.getUser(), session, nextRefreshToken)
        );
    }
}
