package ua.kyiv.drive.kyiv_drive.service;

import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import lombok.RequiredArgsConstructor;
import org.hibernate.exception.ConstraintViolationException;
import org.springframework.context.MessageSource;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;
import ua.kyiv.drive.kyiv_drive.dto.user.AuthResponseDTO;
import ua.kyiv.drive.kyiv_drive.dto.user.GoogleRegisterRequestDTO;
import ua.kyiv.drive.kyiv_drive.dto.user.PreRegisterRequestDTO;
import ua.kyiv.drive.kyiv_drive.dto.user.RegisterRequestDTO;
import ua.kyiv.drive.kyiv_drive.entity.User;
import ua.kyiv.drive.kyiv_drive.exception.FieldValidationException;
import ua.kyiv.drive.kyiv_drive.repository.UserRepository;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class RegistrationService {

    private static final String USER_EMAIL_UNIQUE_CONSTRAINT = "uk_user_email";

    private final OtpService otpService;
    private final GoogleIdTokenService googleIdTokenService;
    private final PasswordEncoder passwordEncoder;
    private final UserSessionService userSessionService;
    private final UserRepository userRepository;
    private final MessageSource messageSource;

    public void sendRegistrationCode(PreRegisterRequestDTO request) {
        if (userRepository.findByEmail(request.getEmail()) != null) {
            throw new FieldValidationException("email", getMessage("error.email_exists"));
        }
        otpService.sendCode(request.getEmail());
    }

    @Transactional
    public AuthResponseDTO register(RegisterRequestDTO request) {
        ensureEmailIsAvailable(request.getEmail());
        otpService.validateCode(request.getEmail(), request.getCode());

        User user = new User();
        user.setName(request.getName());
        user.setEmail(request.getEmail());
        user.setPassword(passwordEncoder.encode(request.getPassword()));
        user.setCurrentMode(request.getCurrentMode());
        user = saveNewUser(user);

        return userSessionService.startSession(user, request.getDevice());
    }

    @Transactional
    public AuthResponseDTO registerViaGoogle(GoogleRegisterRequestDTO request) {
        GoogleIdToken.Payload payload = googleIdTokenService.verify(request.getIdToken());
        String email = payload.getEmail();
        ensureEmailIsAvailable(email);

        User user = new User();
        user.setEmail(email);
        user.setName(request.getName());
        user.setPassword(null);
        user.setCurrentMode(request.getCurrentMode());
        if (StringUtils.hasText(request.getAvatarUrl())) {
            user.setAvatarUrl(request.getAvatarUrl());
        }
        user = saveNewUser(user);

        return userSessionService.startSession(user, request.getDevice());
    }

    private void ensureEmailIsAvailable(String email) {
        if (userRepository.findByEmail(email) != null) {
            throw emailAlreadyExists();
        }
    }

    private User saveNewUser(User user) {
        try {
            return userRepository.saveAndFlush(user);
        } catch (DataIntegrityViolationException exception) {
            if (isEmailUniqueConstraintViolation(exception)) {
                throw emailAlreadyExists();
            }
            throw exception;
        }
    }

    private boolean isEmailUniqueConstraintViolation(Throwable exception) {
        Throwable current = exception;
        while (current != null) {
            if (current instanceof ConstraintViolationException constraintViolation
                    && USER_EMAIL_UNIQUE_CONSTRAINT.equalsIgnoreCase(constraintViolation.getConstraintName())) {
                return true;
            }
            current = current.getCause();
        }
        return false;
    }

    private FieldValidationException emailAlreadyExists() {
        return new FieldValidationException("email", getMessage("error.email_exists"));
    }

    private String getMessage(String code) {
        return messageSource.getMessage(code, null, LocaleContextHolder.getLocale());
    }
}
