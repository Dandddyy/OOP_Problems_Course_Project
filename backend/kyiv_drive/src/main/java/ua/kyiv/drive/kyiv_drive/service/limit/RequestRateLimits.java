package ua.kyiv.drive.kyiv_drive.service.limit;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import ua.kyiv.drive.kyiv_drive.config.RequestRateLimitProperties;
import ua.kyiv.drive.kyiv_drive.config.TripSearchAdmissionProperties;
import ua.kyiv.drive.kyiv_drive.config.SearchCacheProperties;

import java.time.Duration;
import java.util.UUID;

import static ua.kyiv.drive.kyiv_drive.service.limit.RedisRateLimiter.Window;
import static ua.kyiv.drive.kyiv_drive.service.limit.RedisRateLimiter.WindowQuota;

@Service
@RequiredArgsConstructor
public class RequestRateLimits {
    private final RedisRateLimiter redis;
    private final RequestRateLimitProperties properties;
    private final TripSearchAdmissionProperties search;
    private final SearchCacheProperties cache;

    public void account(UUID account) {
        redis.requireBucket("account", account.toString(), properties.getAccountPerMinute(), properties.getAccountBurst());
    }

    public void publicApi(String ip) {
        redis.requireBucket("public", ip, properties.getPublicPerMinute(), properties.getPublicBurst());
    }

    public void loginIp(String ip) {
        redis.requireWindow("login-ip", ip, "rate_limited",
                new Window(Duration.ofMinutes(1), properties.getLoginPerIpPerMinute()));
    }

    public void otpSendIp(String ip) {
        redis.requireWindow("otp-send-ip", ip, "too_often_code_request",
                new Window(Duration.ofMinutes(15), properties.getOtpSendPerIpPerFifteenMinutes()));
    }

    public RedisRateLimiter.Receipt otpSendEmail(String email) {
        return redis.requireWindow("otp-send-email", email, "too_often_code_request",
                new Window(Duration.ofMinutes(15), properties.getOtpSendPerEmailPerFifteenMinutes()));
    }

    public void carRoute(UUID account) {
        redis.requireWindows(account.toString(), carRouteQuota());
    }

    public void newSearchWithCarRoute(UUID account) {
        var searchQuota = new WindowQuota("search", "trip_search_rate_limited",
                new Window(Duration.ofMinutes(1), search.getNewSearchesPerMinute()),
                new Window(Duration.ofHours(1), search.getNewSearchesPerHour()));
        redis.requireWindows(account.toString(), searchQuota, carRouteQuota());
    }

    private WindowQuota carRouteQuota() {
        return new WindowQuota("car-route", "rate_limited",
                new Window(Duration.ofMinutes(1), properties.getCarRoutesPerAccountPerMinute()));
    }

    public void recalculate(UUID account) {
        redis.requireWindow("search-recalculate", account.toString(), "trip_search_rate_limited",
                new Window(Duration.ofMinutes(1), search.getRecalculationsPerMinute()));
    }

    public void keepAlive(UUID account, UUID session, UUID context) {
        redis.requireWindow("search-keep-alive", account + ":" + session + ":" + context, "trip_search_rate_limited",
                new Window(Duration.ofMinutes(1), cache.getKeepAlivesPerMinute()));
    }
}
