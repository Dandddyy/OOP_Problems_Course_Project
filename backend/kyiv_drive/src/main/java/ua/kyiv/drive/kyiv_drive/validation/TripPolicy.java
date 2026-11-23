package ua.kyiv.drive.kyiv_drive.validation;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.ZoneId;

public final class TripPolicy {
    public static final ZoneId TIME_ZONE = ZoneId.of("Europe/Kyiv");
    public static final int MAX_DEPARTURE_DAYS_AHEAD = 30;
    public static final Duration CONFIRMATION_TTL = Duration.ofDays(14);
    public static final BigDecimal FIXED_PRICE_UPPER_BOUND = new BigDecimal("1000");
    public static final BigDecimal PER_KM_PRICE_UPPER_BOUND = new BigDecimal("100");

    private TripPolicy() {
        throw new IllegalStateException("Utility class");
    }
}
