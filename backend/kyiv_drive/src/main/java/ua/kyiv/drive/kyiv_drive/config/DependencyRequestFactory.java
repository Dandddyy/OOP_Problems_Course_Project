package ua.kyiv.drive.kyiv_drive.config;

import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.StreamingHttpOutputMessage;
import org.springframework.http.client.AbstractStreamingClientHttpRequest;
import org.springframework.http.client.ClientHttpRequest;
import org.springframework.http.client.ClientHttpRequestFactory;
import org.springframework.http.client.ClientHttpResponse;
import org.springframework.http.client.JdkClientHttpRequestFactory;

import java.io.IOException;
import java.io.InputStream;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpTimeoutException;
import java.time.Duration;
import java.util.Map;

public final class DependencyRequestFactory implements ClientHttpRequestFactory, AutoCloseable {
    private final Map<String, Endpoint> endpoints;

    public DependencyRequestFactory(TimeoutProperties properties) {
        endpoints = Map.of(
                "osrm_car", endpoint(properties.getCarOsrmConnect(), properties.getCarOsrmResponse()),
                "geoapify", endpoint(properties.getGeoapifyConnect(), properties.getGeoapifyResponse()),
                "brevo", endpoint(properties.getBrevoConnect(), properties.getBrevoTotal()));
    }

    @Override
    public ClientHttpRequest createRequest(URI uri, HttpMethod method) throws IOException {
        String dependencyName = dependency(uri);
        Endpoint endpoint = endpoints.getOrDefault(dependencyName, endpoints.get("osrm_car"));
        return new AbstractStreamingClientHttpRequest() {
            @Override public HttpMethod getMethod() { return method; }
            @Override public URI getURI() { return uri; }

            @Override
            protected ClientHttpResponse executeInternal(HttpHeaders headers, Body body) throws IOException {
                long timeoutMs = OperationDeadline.cap(endpoint.budget()).toMillis();
                var factory = new JdkClientHttpRequestFactory(endpoint.client());
                factory.setReadTimeout(Duration.ofMillis(timeoutMs));
                var request = factory.createRequest(uri, method);
                request.getHeaders().putAll(headers);
                if ("osrm_car".equals(dependencyName)
                        && !request.getHeaders().containsHeader(HttpHeaders.ACCEPT_ENCODING)) {
                    // OSRM can label gzip data as deflate; avoid the default gzip+deflate offer.
                    request.getHeaders().set(HttpHeaders.ACCEPT_ENCODING, "gzip");
                }
                if (body != null) ((StreamingHttpOutputMessage) request).setBody(body);
                long deadline = System.nanoTime() + Duration.ofMillis(timeoutMs).toNanos();
                return new DeadlineResponse(request.execute(), deadline);
            }
        };
    }

    public static String dependency(URI uri) {
        if ("api.geoapify.com".equals(uri.getHost())) return "geoapify";
        if ("api.brevo.com".equals(uri.getHost())) return "brevo";
        if (uri.getPath().contains("/route/v1/driving/")) return "osrm_car";
        return "other";
    }

    private static Endpoint endpoint(Duration connect, Duration budget) {
        return new Endpoint(HttpClient.newBuilder().connectTimeout(connect)
                .version(HttpClient.Version.HTTP_1_1).build(), budget);
    }

    @Override
    public void close() {
        endpoints.values().forEach(endpoint -> endpoint.client().shutdownNow());
    }

    private record Endpoint(HttpClient client, Duration budget) {}

    // Spring closes a stalled body, which the JDK reports as a generic IOException.
    private record DeadlineResponse(ClientHttpResponse response, long deadline) implements ClientHttpResponse {
        @Override public HttpStatusCode getStatusCode() throws IOException { return response.getStatusCode(); }
        @Override public String getStatusText() throws IOException { return response.getStatusText(); }
        @Override public HttpHeaders getHeaders() { return response.getHeaders(); }
        @Override public void close() { response.close(); }

        @Override
        public InputStream getBody() throws IOException {
            InputStream body = response.getBody();
            return new InputStream() {
                @Override
                public int read() throws IOException {
                    try {
                        return body.read();
                    } catch (IOException failure) {
                        throw classify(failure);
                    }
                }

                @Override
                public int read(byte[] target, int offset, int length) throws IOException {
                    try {
                        return body.read(target, offset, length);
                    } catch (IOException failure) {
                        throw classify(failure);
                    }
                }

                @Override public void close() throws IOException { body.close(); }
            };
        }

        private IOException classify(IOException failure) {
            if (System.nanoTime() - deadline < 0) return failure;
            var timeout = new HttpTimeoutException("HTTP response body timed out");
            timeout.initCause(failure);
            return timeout;
        }
    }
}
