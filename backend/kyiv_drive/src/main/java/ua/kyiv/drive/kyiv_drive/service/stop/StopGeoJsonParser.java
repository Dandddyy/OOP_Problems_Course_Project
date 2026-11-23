package ua.kyiv.drive.kyiv_drive.service.stop;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import ua.kyiv.drive.kyiv_drive.config.OperationDeadline;
import ua.kyiv.drive.kyiv_drive.config.StopImportProperties;
import ua.kyiv.drive.kyiv_drive.exception.FileProcessingException;
import ua.kyiv.drive.kyiv_drive.exception.FileValidationException;

import java.io.IOException;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Component
@RequiredArgsConstructor
public class StopGeoJsonParser {

    private static final Pattern OSM_ID_PATTERN = Pattern.compile("^(node|way|relation)/([1-9][0-9]*)$");
    private static final int MAX_REPORTED_ERRORS = 20;

    private final ObjectMapper objectMapper;
    private final StopImportProperties properties;

    public StopImportDataset parse(MultipartFile file) {
        OperationDeadline.check();
        validateFile(file);

        byte[] fileContent = readFile(file);
        OperationDeadline.check();
        JsonNode root = readRoot(fileContent);
        validateRoot(root);

        JsonNode features = root.get("features");
        List<ParsedStop> stops = new ArrayList<>();
        List<String> errors = new ArrayList<>();
        Set<Long> processedOsmIds = new HashSet<>();
        int outOfBoundsFeatureCount = 0;
        int invalidFeatureCount = 0;

        for (int index = 0; index < features.size(); index++) {
            OperationDeadline.check();
            try {
                ParsedStop stop = parseFeature(features.get(index));

                if (!processedOsmIds.add(stop.osmId())) {
                    throw new IllegalArgumentException("duplicate OSM id node/" + stop.osmId());
                }

                if (isWithinImportBounds(stop)) {
                    stops.add(stop);
                } else {
                    outOfBoundsFeatureCount++;
                }
            } catch (IllegalArgumentException exception) {
                invalidFeatureCount++;
                if (errors.size() < MAX_REPORTED_ERRORS) {
                    errors.add("features[" + index + "]: " + exception.getMessage());
                }
            }
        }

        if (invalidFeatureCount > 0) {
            throw new FileValidationException(formatValidationErrors(invalidFeatureCount, errors));
        }

        if (stops.size() < properties.getMinimumAcceptedStops()) {
            throw new FileValidationException(
                    "The file contains only " + stops.size() + " stops inside the import area; at least "
                            + properties.getMinimumAcceptedStops() + " are required."
            );
        }

        return new StopImportDataset(
                stops,
                features.size(),
                outOfBoundsFeatureCount,
                Sha256Support.hash(fileContent)
        );
    }

    private void validateFile(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new FileValidationException("Empty file.");
        }

        String filename = file.getOriginalFilename();
        if (filename != null && !filename.toLowerCase(Locale.ROOT).endsWith(".geojson")) {
            throw new FileValidationException("Invalid file format. Expected .geojson");
        }
    }

    private byte[] readFile(MultipartFile file) {
        try {
            return file.getBytes();
        } catch (IOException exception) {
            throw new FileProcessingException("Could not read the uploaded file.");
        }
    }

    private JsonNode readRoot(byte[] fileContent) {
        try {
            return objectMapper.readTree(fileContent);
        } catch (JacksonException exception) {
            throw new FileValidationException("The file is not valid JSON.");
        }
    }

    private void validateRoot(JsonNode root) {
        if (root == null || !root.isObject()) {
            throw new FileValidationException("GeoJSON root must be an object.");
        }

        if (!"FeatureCollection".equals(root.path("type").asString(null))) {
            throw new FileValidationException("GeoJSON root type must be 'FeatureCollection'.");
        }

        JsonNode features = root.get("features");
        if (features == null || !features.isArray() || features.isEmpty()) {
            throw new FileValidationException("GeoJSON must contain a non-empty 'features' array.");
        }
    }

    private ParsedStop parseFeature(JsonNode feature) {
        if (feature == null || !feature.isObject()) {
            throw new IllegalArgumentException("feature must be an object");
        }

        if (!"Feature".equals(feature.path("type").asString(null))) {
            throw new IllegalArgumentException("type must be 'Feature'");
        }

        JsonNode propertiesNode = feature.get("properties");
        if (propertiesNode == null || !propertiesNode.isObject()) {
            throw new IllegalArgumentException("properties must be an object");
        }

        long osmId = parseOsmId(feature.get("id"), propertiesNode.get("@id"));
        String name = parseName(propertiesNode.get("name"));

        JsonNode geometryNode = feature.get("geometry");
        if (geometryNode == null || !geometryNode.isObject()) {
            throw new IllegalArgumentException("geometry must be an object");
        }

        if (!"Point".equals(geometryNode.path("type").asString(null))) {
            throw new IllegalArgumentException("geometry type must be 'Point'");
        }

        JsonNode coordinatesNode = geometryNode.get("coordinates");
        if (coordinatesNode == null || !coordinatesNode.isArray() || coordinatesNode.size() < 2) {
            throw new IllegalArgumentException("Point coordinates must contain longitude and latitude");
        }

        double lon = parseCoordinate(coordinatesNode.get(0), "longitude", -180.0, 180.0);
        double lat = parseCoordinate(coordinatesNode.get(1), "latitude", -90.0, 90.0);

        return new ParsedStop(osmId, name, lat, lon);
    }

    private long parseOsmId(JsonNode featureIdNode, JsonNode propertyIdNode) {
        String featureId = optionalText(featureIdNode, "id");
        String propertyId = optionalText(propertyIdNode, "properties.@id");

        if (featureId == null && propertyId == null) {
            throw new IllegalArgumentException("OSM id is missing");
        }

        if (featureId != null && propertyId != null && !featureId.equals(propertyId)) {
            throw new IllegalArgumentException("id and properties.@id do not match");
        }

        String rawId = featureId != null ? featureId : propertyId;
        Matcher matcher = OSM_ID_PATTERN.matcher(rawId);
        if (!matcher.matches()) {
            throw new IllegalArgumentException("OSM id must have format node/<positive integer>");
        }

        if (!"node".equals(matcher.group(1))) {
            throw new IllegalArgumentException("only OSM node elements are supported");
        }

        try {
            return Long.parseLong(matcher.group(2));
        } catch (NumberFormatException exception) {
            throw new IllegalArgumentException("OSM id is outside the supported 64-bit range");
        }
    }

    private String optionalText(JsonNode node, String fieldName) {
        if (node == null || node.isNull()) {
            return null;
        }
        if (!node.isString()) {
            throw new IllegalArgumentException(fieldName + " must be a string");
        }
        return node.stringValue();
    }

    private String parseName(JsonNode nameNode) {
        String name = optionalText(nameNode, "properties.name");
        if (name == null || name.isBlank()) {
            return null;
        }
        return name.trim();
    }

    private double parseCoordinate(JsonNode coordinateNode, String name, double minimum, double maximum) {
        if (coordinateNode == null || !coordinateNode.isNumber()) {
            throw new IllegalArgumentException(name + " must be numeric");
        }

        double value = coordinateNode.doubleValue();
        if (!Double.isFinite(value) || value < minimum || value > maximum) {
            throw new IllegalArgumentException(name + " is outside the valid range");
        }
        return value;
    }

    private boolean isWithinImportBounds(ParsedStop stop) {
        return stop.lat() >= properties.getMinLat()
                && stop.lat() <= properties.getMaxLat()
                && stop.lon() >= properties.getMinLon()
                && stop.lon() <= properties.getMaxLon();
    }

    private String formatValidationErrors(int invalidFeatureCount, List<String> errors) {
        StringBuilder message = new StringBuilder("GeoJSON contains ")
                .append(invalidFeatureCount)
                .append(" invalid feature(s): ")
                .append(String.join("; ", errors));

        if (invalidFeatureCount > errors.size()) {
            message.append("; and ")
                    .append(invalidFeatureCount - errors.size())
                    .append(" more");
        }
        return message.toString();
    }
}
