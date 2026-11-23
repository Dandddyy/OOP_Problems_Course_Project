package ua.kyiv.drive.kyiv_drive.service.limit;

import io.micrometer.core.instrument.MeterRegistry;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.ClassPathResource;
import org.springframework.dao.DataAccessException;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.RedisScript;
import org.springframework.stereotype.Service;
import ua.kyiv.drive.kyiv_drive.auth.TokenHash;
import ua.kyiv.drive.kyiv_drive.exception.RateLimitException;

import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class RedisRateLimiter {
    private static final RedisScript<Long> BUCKET = script("rate_limit_bucket.lua");
    private static final RedisScript<Long> WINDOW = script("rate_limit_window.lua");

    private final StringRedisTemplate redis;
    private final MeterRegistry meters;

    record Window(Duration duration, int limit) {}
    record WindowQuota(String policy, String error, Window... windows) {}
    public record Receipt(String key, String member) {}

    void requireBucket(String policy, String subject, int perMinute, int burst) {
        if (execute(BUCKET, List.of(key(policy, subject)), Integer.toString(perMinute), Integer.toString(burst)) == 0) {
            throw reject(policy, "rate_limited");
        }
    }

    Receipt requireWindow(String policy, String subject, String error, Window... windows) {
        return reserve(subject, new WindowQuota(policy, error, windows));
    }

    void requireWindows(String subject, WindowQuota... quotas) {
        reserve(subject, quotas);
    }

    private Receipt reserve(String subject, WindowQuota... quotas) {
        String member = UUID.randomUUID().toString();
        List<String> keys = new ArrayList<>();
        List<String> args = new ArrayList<>();
        args.add(member);
        args.add(Integer.toString(quotas.length));
        for (WindowQuota quota : quotas) {
            keys.add(key(quota.policy(), subject));
            args.add(Integer.toString(quota.windows().length));
            for (Window window : quota.windows()) {
                args.add(Long.toString(window.duration().toMillis()));
                args.add(Integer.toString(window.limit()));
            }
        }
        long rejected = execute(WINDOW, keys, args.toArray(String[]::new));
        if (rejected > 0) {
            WindowQuota quota = quotas[(int) rejected - 1];
            throw reject(quota.policy(), quota.error());
        }
        return new Receipt(keys.getFirst(), member);
    }

    public void refund(Receipt receipt) {
        try {
            redis.opsForZSet().remove(receipt.key(), receipt.member());
        } catch (DataAccessException e) {
            throw RateLimitException.unavailable(e);
        }
    }

    public long execute(RedisScript<Long> script, List<String> keys, String... args) {
        try {
            Long result = redis.execute(script, keys, (Object[]) args);
            if (result == null) throw RateLimitException.unavailable(null);
            return result;
        } catch (DataAccessException e) {
            throw RateLimitException.unavailable(e);
        }
    }

    private static String key(String policy, String subject) {
        return "rate-limit:v1:" + policy + ":" + TokenHash.sha256(subject);
    }

    public static RedisScript<Long> script(String file) {
        return RedisScript.of(new ClassPathResource("redis/" + file), Long.class);
    }

    private RateLimitException reject(String policy, String code) {
        meters.counter("kyivdrive.rate_limit.rejections", "policy", policy).increment();
        return new RateLimitException(code);
    }
}
