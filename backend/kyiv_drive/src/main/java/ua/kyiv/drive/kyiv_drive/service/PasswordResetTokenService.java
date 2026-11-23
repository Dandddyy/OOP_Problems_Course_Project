package ua.kyiv.drive.kyiv_drive.service;

import lombok.RequiredArgsConstructor;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.stereotype.Service;
import ua.kyiv.drive.kyiv_drive.auth.TokenHash;
import ua.kyiv.drive.kyiv_drive.config.PasswordResetProperties;

import java.nio.ByteBuffer;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Instant;
import java.util.Base64;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class PasswordResetTokenService {

    private static final int UUID_BYTES = 16;
    private static final int RANDOM_BYTES = 32;
    private static final int TOKEN_BYTES = UUID_BYTES + RANDOM_BYTES;
    private static final long TOKEN_CONSUMED = 1;
    private static final String KEY_PREFIX = "password_reset:";
    private static final DefaultRedisScript<Long> CONSUME_TOKEN_SCRIPT = new DefaultRedisScript<>("""
            local savedHash = redis.call('GET', KEYS[1])
            if not savedHash or savedHash ~= ARGV[1] then
                return 0
            end
            redis.call('DEL', KEYS[1])
            return 1
            """, Long.class);

    private final StringRedisTemplate redisTemplate;
    private final Clock clock;
    private final PasswordResetProperties properties;
    private final SecureRandom secureRandom = new SecureRandom();

    public PasswordResetGrant issue(UUID userId) {
        byte[] bytes = new byte[TOKEN_BYTES];
        secureRandom.nextBytes(bytes);
        ByteBuffer.wrap(bytes)
                .putLong(userId.getMostSignificantBits())
                .putLong(userId.getLeastSignificantBits());
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
        Instant expiresAt = clock.instant().plus(properties.getTokenTtl());
        redisTemplate.opsForValue().set(key(userId), TokenHash.sha256(token), properties.getTokenTtl());
        return new PasswordResetGrant(token, expiresAt);
    }

    public Optional<UUID> consume(String token) {
        Optional<UUID> userId = extractUserId(token);
        if (userId.isEmpty()) {
            return Optional.empty();
        }

        Long result = redisTemplate.execute(
                CONSUME_TOKEN_SCRIPT,
                List.of(key(userId.get())),
                TokenHash.sha256(token)
        );
        return result != null && result == TOKEN_CONSUMED ? userId : Optional.empty();
    }

    private Optional<UUID> extractUserId(String token) {
        if (token == null) {
            return Optional.empty();
        }

        try {
            byte[] bytes = Base64.getUrlDecoder().decode(token);
            if (bytes.length != TOKEN_BYTES) {
                return Optional.empty();
            }
            ByteBuffer buffer = ByteBuffer.wrap(bytes);
            return Optional.of(new UUID(buffer.getLong(), buffer.getLong()));
        } catch (IllegalArgumentException e) {
            return Optional.empty();
        }
    }

    private String key(UUID userId) {
        return KEY_PREFIX + userId;
    }

    public record PasswordResetGrant(String token, Instant expiresAt) {
    }
}
