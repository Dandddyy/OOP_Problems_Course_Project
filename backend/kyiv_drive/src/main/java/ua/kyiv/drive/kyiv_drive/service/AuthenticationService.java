package ua.kyiv.drive.kyiv_drive.service;

import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import lombok.RequiredArgsConstructor;
import org.springframework.context.MessageSource;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.data.redis.core.script.RedisScript;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;
import ua.kyiv.drive.kyiv_drive.auth.TokenHash;
import ua.kyiv.drive.kyiv_drive.config.RequestRateLimitProperties;
import ua.kyiv.drive.kyiv_drive.dto.user.AuthResponseDTO;
import ua.kyiv.drive.kyiv_drive.dto.user.GoogleLoginRequestDTO;
import ua.kyiv.drive.kyiv_drive.dto.user.LoginRequestDTO;
import ua.kyiv.drive.kyiv_drive.entity.User;
import ua.kyiv.drive.kyiv_drive.exception.RateLimitException;
import ua.kyiv.drive.kyiv_drive.exception.UserNotRegisteredException;
import ua.kyiv.drive.kyiv_drive.repository.UserRepository;
import ua.kyiv.drive.kyiv_drive.service.limit.RedisRateLimiter;

import javax.security.auth.login.AccountLockedException;
import javax.security.auth.login.CredentialException;
import java.time.Duration;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AuthenticationService {

    private static final RedisScript<Long> LOGIN_ATTEMPTS = RedisRateLimiter.script("login_attempts.lua");
    private static final Duration LOGIN_BLOCK = Duration.ofMinutes(15);

    private final RedisRateLimiter rateLimiter;
    private final RequestRateLimitProperties rateProperties;
    private final PasswordEncoder passwordEncoder;
    private final UserSessionService userSessionService;
    private final GoogleIdTokenService googleIdTokenService;
    private final UserRepository userRepository;
    private final MessageSource messageSource;

    @Transactional
    public AuthResponseDTO login(LoginRequestDTO request) throws CredentialException, AccountLockedException {
        String email = request.getEmail();
        try (var attempt = new LoginAttempt(email)) {
            User user = userRepository.findByEmail(email);
            if (user != null && user.getPassword() == null) {
                throw new CredentialException(getMessage("error.login_via_google"));
            }
            if (user == null || !passwordEncoder.matches(request.getPassword(), user.getPassword())) {
                if (attempt.finish("failure") >= rateProperties.getFailedLoginsPerEmail()) {
                    throw new RateLimitException("too_many_login_attempts");
                }
                throw new CredentialException(getMessage("error.incorrect_email_or_password"));
            }
            if (!user.getIsActive()) {
                throw new AccountLockedException(getMessage("error.account_deactivated"));
            }

            attempt.finish("success");
            return userSessionService.startSession(user, request.getDevice());
        }
    }

    @Transactional
    public AuthResponseDTO loginViaGoogle(GoogleLoginRequestDTO request) throws AccountLockedException {
        GoogleIdToken.Payload payload = googleIdTokenService.verify(request.getIdToken());
        User user = userRepository.findByEmail(payload.getEmail());

        if (user == null) {
            String firstName = (String) payload.get("given_name");
            if (firstName == null) {
                firstName = (String) payload.get("name");
            }
            throw new UserNotRegisteredException(firstName);
        }
        if (!user.getIsActive()) {
            throw new AccountLockedException(getMessage("error.account_deactivated"));
        }
        if (StringUtils.hasText(request.getAvatarUrl()) && !StringUtils.hasText(user.getAvatarUrl())) {
            user.setAvatarUrl(request.getAvatarUrl());
        }

        return userSessionService.startSession(user, request.getDevice());
    }

    private final class LoginAttempt implements AutoCloseable {
        private final List<String> keys;
        private final String id = UUID.randomUUID().toString();
        private boolean finished;

        private LoginAttempt(String email) {
            keys = List.of("login_attempts:" + email, "login_pending:" + TokenHash.sha256(email));
            apply("reserve");
        }

        private long finish(String action) {
            long attempts = apply(action);
            finished = true;
            return attempts;
        }

        private long apply(String action) {
            long attempts = rateLimiter.execute(LOGIN_ATTEMPTS, keys, action, id,
                    Integer.toString(rateProperties.getFailedLoginsPerEmail()), Long.toString(LOGIN_BLOCK.toMillis()));
            if (attempts == -1) throw new RateLimitException("too_many_login_attempts");
            if (attempts == -2) throw RateLimitException.unavailable(null);
            return attempts;
        }

        @Override
        public void close() {
            if (!finished) apply("release");
        }
    }

    private String getMessage(String code) {
        return messageSource.getMessage(code, null, LocaleContextHolder.getLocale());
    }
}
