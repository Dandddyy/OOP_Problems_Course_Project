package ua.kyiv.drive.kyiv_drive.config;

import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.client.ClientHttpRequest;
import org.springframework.http.client.ClientHttpRequestFactory;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import ua.kyiv.drive.kyiv_drive.exception.TripSearchException;

import java.io.IOException;
import java.net.URI;
import java.time.Duration;
import java.util.function.Supplier;

public final class WalkingOsrmRequestFactory implements ClientHttpRequestFactory {
    private final WalkingRoutingProperties properties;
    private final ThreadLocal<Long> requestDeadline = new ThreadLocal<>();

    public WalkingOsrmRequestFactory(WalkingRoutingProperties properties) {
        this.properties = properties;
    }

    public <T> T withDeadline(long deadlineNanos, Supplier<T> action) {
        Long previous = requestDeadline.get();
        requestDeadline.set(deadlineNanos);
        try {
            return action.get();
        } finally {
            if (previous == null) requestDeadline.remove();
            else requestDeadline.set(previous);
        }
    }

    @Override
    public ClientHttpRequest createRequest(URI uri, HttpMethod method) throws IOException {
        Long deadline = requestDeadline.get();
        if (deadline == null) throw new IllegalStateException("Missing walking routing deadline");
        long remainingNanos = deadline - System.nanoTime();
        if (remainingNanos <= 0) {
            throw new TripSearchException("trip_search_busy", HttpStatus.SERVICE_UNAVAILABLE);
        }
        var remaining = Duration.ofNanos(remainingNanos);
        var factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(boundedTimeout(properties.getConnectTimeout(), remaining));
        factory.setReadTimeout(boundedTimeout(properties.getReadTimeout(), remaining));
        return factory.createRequest(uri, method);
    }

    private static int boundedTimeout(Duration configured, Duration remaining) {
        long milliseconds = Math.min(configured.toMillis(), remaining.toMillis());
        return (int) Math.max(1, Math.min(Integer.MAX_VALUE, milliseconds));
    }
}
