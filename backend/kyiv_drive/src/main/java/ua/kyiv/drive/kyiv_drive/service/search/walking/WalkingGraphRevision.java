package ua.kyiv.drive.kyiv_drive.service.search.walking;

import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import tools.jackson.databind.ObjectMapper;
import ua.kyiv.drive.kyiv_drive.config.WalkingRoutingProperties;
import ua.kyiv.drive.kyiv_drive.exception.TripSearchException;

import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;

@Component
@RequiredArgsConstructor
public class WalkingGraphRevision {
    private final WalkingRoutingProperties properties;
    private final ObjectMapper mapper;

    public Identity current() {
        if (properties.getGraphRevision() != null && !properties.getGraphRevision().isBlank()) {
            return new Identity(properties.getGraphRevision(), properties.getExpectedDataVersion());
        }
        Path manifest = findManifest();
        if (manifest == null) throw unavailable(null);
        try {
            byte[] bytes = Files.readAllBytes(manifest);
            var root = mapper.readTree(bytes);
            if (!"ready".equals(root.path("status").asString())
                    || root.path("release_id").asString("").isBlank()) throw unavailable(null);
            Path info = manifest.getParent().resolve("region-fileinfo.json");
            String dataVersion = properties.getExpectedDataVersion();
            if (Files.isRegularFile(info)) {
                String recordedVersion = mapper.readTree(Files.readAllBytes(info)).path("header")
                        .path("option").path("osmosis_replication_timestamp").asString("");
                if (!recordedVersion.isBlank()) {
                    if (dataVersion != null && !dataVersion.isBlank() && !dataVersion.equals(recordedVersion)) {
                        throw new TripSearchException("trip_search_graph_changed", HttpStatus.CONFLICT);
                    }
                    dataVersion = recordedVersion;
                }
            }
            return new Identity(sha256(bytes), dataVersion);
        } catch (TripSearchException e) {
            throw e;
        } catch (java.io.IOException | tools.jackson.core.JacksonException e) {
            throw unavailable(e);
        }
    }

    private Path findManifest() {
        if (properties.getManifestPath() != null && !properties.getManifestPath().isBlank()) {
            Path path = Path.of(properties.getManifestPath());
            return Files.isRegularFile(path) ? path : null;
        }
        for (Path path = Path.of("").toAbsolutePath(); path != null; path = path.getParent()) {
            Path candidate = path.resolve("osrm-data/current/manifest.json");
            if (Files.isRegularFile(candidate)) return candidate;
        }
        return null;
    }

    static String sha256(byte[] value) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(value));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 is required by the Java runtime", e);
        }
    }

    private static TripSearchException unavailable(Throwable cause) {
        return new TripSearchException("trip_search_routing_unavailable", HttpStatus.SERVICE_UNAVAILABLE, cause);
    }

    public record Identity(String revision, String expectedDataVersion) {
    }
}
