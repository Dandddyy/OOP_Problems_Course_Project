package ua.kyiv.drive.kyiv_drive.service;

import lombok.RequiredArgsConstructor;
import org.springframework.context.MessageSource;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import ua.kyiv.drive.kyiv_drive.dto.user.AuthResponseDTO;
import ua.kyiv.drive.kyiv_drive.dto.user.DeviceContextDTO;
import ua.kyiv.drive.kyiv_drive.dto.user.PasswordResetTokenResponseDTO;
import ua.kyiv.drive.kyiv_drive.entity.User;
import ua.kyiv.drive.kyiv_drive.exception.OtpException;
import ua.kyiv.drive.kyiv_drive.repository.UserRepository;

import java.util.UUID;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class PasswordRecoveryService {

    private final OtpService otpService;
    private final PasswordResetTokenService passwordResetTokenService;
    private final PasswordEncoder passwordEncoder;
    private final UserSessionService userSessionService;
    private final UserRepository userRepository;
    private final MessageSource messageSource;

    public void sendCode(String email) {
        if (userRepository.findByEmail(email) == null) {
            return;
        }
        otpService.sendCode(email);
    }

    public PasswordResetTokenResponseDTO verifyCode(String email, String userCode) {
        otpService.validateCode(email, userCode);
        User user = userRepository.findByEmail(email);
        if (user == null) {
            throw new IllegalArgumentException("User not found");
        }

        PasswordResetTokenService.PasswordResetGrant grant = passwordResetTokenService.issue(user.getId());
        return new PasswordResetTokenResponseDTO(grant.token(), grant.expiresAt());
    }

    @Transactional
    public AuthResponseDTO resetPassword(String newPassword, String resetToken, DeviceContextDTO device) {
        UUID userId = passwordResetTokenService.consume(resetToken)
                .orElseThrow(() -> new OtpException(getMessage("error.reset_password_timeout")));
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));

        user.setPassword(passwordEncoder.encode(newPassword));
        userSessionService.deleteAllSessions(userId);
        return userSessionService.startSession(user, device);
    }

    private String getMessage(String code) {
        return messageSource.getMessage(code, null, LocaleContextHolder.getLocale());
    }
}
