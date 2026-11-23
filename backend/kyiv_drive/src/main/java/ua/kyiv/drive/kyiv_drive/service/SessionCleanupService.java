package ua.kyiv.drive.kyiv_drive.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import ua.kyiv.drive.kyiv_drive.repository.UserSessionRepository;

import java.time.Clock;
import java.time.Instant;

@Slf4j
@Service
@RequiredArgsConstructor
public class SessionCleanupService {

    private final UserSessionRepository sessionRepository;
    private final Clock clock;

    @Scheduled(
            cron = "${app.security.sessions.cleanup-cron:0 0 * * * *}",
            zone = "${app.security.sessions.cleanup-zone:UTC}"
    )
    @Transactional
    public void cleanup() {
        Instant now = clock.instant();
        int deleted = sessionRepository.deleteExpiredSessions(now);

        if (deleted > 0) {
            log.info("Session cleanup deleted {} expired sessions", deleted);
        }
    }
}
