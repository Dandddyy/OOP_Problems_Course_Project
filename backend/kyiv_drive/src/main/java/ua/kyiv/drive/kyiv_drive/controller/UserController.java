package ua.kyiv.drive.kyiv_drive.controller;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import ua.kyiv.drive.kyiv_drive.auth.UserPrincipal;
import ua.kyiv.drive.kyiv_drive.dto.user.*;
import ua.kyiv.drive.kyiv_drive.service.AuthenticationService;
import ua.kyiv.drive.kyiv_drive.service.ClientVersionPolicy;
import ua.kyiv.drive.kyiv_drive.service.PasswordRecoveryService;
import ua.kyiv.drive.kyiv_drive.service.RefreshTokenService;
import ua.kyiv.drive.kyiv_drive.service.RegistrationService;
import ua.kyiv.drive.kyiv_drive.service.UserQueryService;
import ua.kyiv.drive.kyiv_drive.service.UserSessionService;

import javax.security.auth.login.AccountLockedException;
import javax.security.auth.login.CredentialException;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping(value = "/api/user")
@RequiredArgsConstructor
public class UserController {

    private final AuthenticationService authenticationService;
    private final RegistrationService registrationService;
    private final PasswordRecoveryService passwordRecoveryService;
    private final UserQueryService userQueryService;
    private final UserSessionService userSessionService;
    private final RefreshTokenService refreshTokenService;
    private final ClientVersionPolicy clientVersionPolicy;

    @GetMapping("/me")
    public ResponseEntity<CurrentUserResponseDTO> getCurrentUser(
            @AuthenticationPrincipal UserPrincipal principal
    ) {
        return ResponseEntity.ok(userQueryService.getCurrentUser(
                principal.getId(),
                principal.getSessionId()
        ));
    }

    @PostMapping("/refresh")
    public ResponseEntity<AuthResponseDTO> refreshToken(
            @Valid @RequestBody RefreshTokenRequestDTO request
    ) throws AccountLockedException, CredentialException {
        clientVersionPolicy.requireSupported(request.getDevice());
        return ResponseEntity.ok(refreshTokenService.refresh(request.getRefreshToken(), request.getDevice()));
    }

    @GetMapping("/out")
    public ResponseEntity<List<UserDTO>> getInactiveUsers() {
        List<UserDTO> inactiveUsers = userQueryService.getInactiveUsers();
        if (inactiveUsers.isEmpty()) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(inactiveUsers);
    }

    @GetMapping("/profile-summary")
    public ResponseEntity<UserRatingResponseDTO> getUserRating(
            @AuthenticationPrincipal UserPrincipal principal
    ) {
        return ResponseEntity.ok(userQueryService.getUserRating(principal.getId()));
    }

    @PostMapping("/login")
    public ResponseEntity<AuthResponseDTO> login(
            @Valid @RequestBody LoginRequestDTO request
    ) throws AccountLockedException, CredentialException {
        clientVersionPolicy.requireSupported(request.getDevice());
        return ResponseEntity.ok(authenticationService.login(request));
    }

    @PostMapping("/send-registration-code")
    public ResponseEntity<Map<String, String>> sendRegistrationCode(
            @Valid @RequestBody PreRegisterRequestDTO request
    ) {
        registrationService.sendRegistrationCode(request);
        return ResponseEntity.ok(Map.of("message", "Registration code sent successfully"));
    }

    @PostMapping("/register")
    public ResponseEntity<AuthResponseDTO> createUser(
            @Valid @RequestBody RegisterRequestDTO request
    ) {
        clientVersionPolicy.requireSupported(request.getDevice());
        return ResponseEntity.status(HttpStatus.CREATED).body(registrationService.register(request));
    }

    @PostMapping("/google/login")
    public ResponseEntity<AuthResponseDTO> googleLogin(
            @Valid @RequestBody GoogleLoginRequestDTO request
    ) throws AccountLockedException {
        clientVersionPolicy.requireSupported(request.getDevice());
        return ResponseEntity.ok(authenticationService.loginViaGoogle(request));
    }

    @PostMapping("/google/register")
    public ResponseEntity<AuthResponseDTO> googleRegister(
            @Valid @RequestBody GoogleRegisterRequestDTO request
    ) {
        clientVersionPolicy.requireSupported(request.getDevice());
        return ResponseEntity.status(HttpStatus.CREATED).body(registrationService.registerViaGoogle(request));
    }

    @PostMapping("/send-code")
    public ResponseEntity<Map<String, String>> sendCode(
            @Valid @RequestBody SendCodeRequestDTO request
    ) {
        passwordRecoveryService.sendCode(request.getEmail());
        return ResponseEntity.ok(Map.of("message", "Code sent successfully"));
    }

    @PostMapping("/verify-code")
    public ResponseEntity<PasswordResetTokenResponseDTO> verifyCode(
            @Valid @RequestBody VerifyCodeRequestDTO request
    ) {
        return ResponseEntity.ok(passwordRecoveryService.verifyCode(request.getEmail(), request.getCode()));
    }

    @PostMapping("/reset-password")
    public ResponseEntity<AuthResponseDTO> resetPassword(
            @Valid @RequestBody ResetPasswordRequestDTO request
    ) {
        clientVersionPolicy.requireSupported(request.getDevice());
        return ResponseEntity.ok(passwordRecoveryService.resetPassword(
                request.getNewPassword(), request.getPasswordResetToken(), request.getDevice()
        ));
    }

    @PostMapping("/switch-mode")
    public ResponseEntity<AccessTokenResponseDTO> switchMode(
            @Valid @RequestBody SwitchModeRequestDTO request,
            @AuthenticationPrincipal UserPrincipal principal
    ) {
        return ResponseEntity.ok(userSessionService.switchMode(
                principal.getId(),
                principal.getSessionId(),
                request.getTargetMode()
        ));
    }

    @PostMapping("/logout")
    public ResponseEntity<Void> logout(@AuthenticationPrincipal UserPrincipal principal) {
        userSessionService.deleteCurrentSession(principal.getId(), principal.getSessionId());
        return ResponseEntity.noContent().build();
    }
}
