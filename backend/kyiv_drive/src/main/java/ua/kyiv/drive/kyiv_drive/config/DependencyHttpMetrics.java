package ua.kyiv.drive.kyiv_drive.config;

import io.micrometer.common.KeyValues;
import io.micrometer.observation.ObservationRegistry;
import org.springframework.http.client.observation.ClientRequestObservationContext;
import org.springframework.http.client.observation.ClientRequestObservationConvention;
import org.springframework.web.client.RestTemplate;

import java.io.IOException;
import java.net.SocketTimeoutException;
import java.net.URI;
import java.net.http.HttpTimeoutException;
import java.util.function.Function;

public final class DependencyHttpMetrics {
    private DependencyHttpMetrics() {}

    public static RestTemplate observe(RestTemplate client, ObservationRegistry registry,
                                       Function<URI, String> dependency) {
        client.setObservationRegistry(registry);
        client.setObservationConvention(new ClientRequestObservationConvention() {
            @Override
            public String getName() {
                return "kyivdrive.dependency.http";
            }

            @Override
            public KeyValues getLowCardinalityKeyValues(ClientRequestObservationContext context) {
                return KeyValues.of("dependency", dependency.apply(context.getCarrier().getURI()),
                        "outcome", outcome(context));
            }
        });
        return client;
    }

    private static String outcome(ClientRequestObservationContext context) {
        if (context.getError() != null) {
            for (Throwable cause = context.getError(); cause != null; cause = cause.getCause()) {
                if (cause instanceof SocketTimeoutException || cause instanceof HttpTimeoutException) {
                    return "timeout";
                }
            }
            return "error";
        }
        var response = context.getResponse();
        if (response == null) return "pending";
        try {
            return response.getStatusCode().isError() ? "error" : "success";
        } catch (IOException e) {
            return "error";
        }
    }
}
