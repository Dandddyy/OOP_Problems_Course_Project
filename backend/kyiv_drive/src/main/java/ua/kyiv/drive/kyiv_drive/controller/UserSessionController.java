package ua.kyiv.drive.kyiv_drive.controller;

import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import ua.kyiv.drive.kyiv_drive.auth.UserPrincipal;
import ua.kyiv.drive.kyiv_drive.dto.user.UserSessionResponseDTO;
import ua.kyiv.drive.kyiv_drive.service.UserSessionService;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/user")
@RequiredArgsConstructor
public class UserSessionController {

    private final UserSessionService userSessionService;

    @GetMapping("/sessions")
    public ResponseEntity<List<UserSessionResponseDTO>> getSessions(
            @AuthenticationPrincipal UserPrincipal principal
    ) {
        return ResponseEntity.ok(userSessionService.getSessions(
                principal.getId(),
                principal.getSessionId()
        ));
    }

    @DeleteMapping("/sessions/{sessionId}")
    public ResponseEntity<Void> deleteSession(
            @PathVariable UUID sessionId,
            @AuthenticationPrincipal UserPrincipal principal
    ) {
        userSessionService.deleteSession(
                principal.getId(),
                principal.getSessionId(),
                sessionId
        );
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/logout-others")
    public ResponseEntity<Void> logoutOthers(@AuthenticationPrincipal UserPrincipal principal) {
        userSessionService.deleteOtherSessions(
                principal.getId(),
                principal.getSessionId()
        );
        return ResponseEntity.noContent().build();
    }
}
