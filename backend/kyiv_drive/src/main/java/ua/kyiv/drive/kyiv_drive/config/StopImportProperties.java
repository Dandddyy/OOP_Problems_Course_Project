package ua.kyiv.drive.kyiv_drive.config;

import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Min;
import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;
import org.springframework.validation.annotation.Validated;
import ua.kyiv.drive.kyiv_drive.validation.ServiceArea;

@Getter
@Setter
@Component
@Validated
@ConfigurationProperties(prefix = "app.stops.import")
public class StopImportProperties {

    private double minLat = ServiceArea.MIN_LATITUDE;
    private double maxLat = ServiceArea.MAX_LATITUDE;
    private double minLon = ServiceArea.MIN_LONGITUDE;
    private double maxLon = ServiceArea.MAX_LONGITUDE;

    @Min(1)
    private int minimumAcceptedStops = 1_000;

    @DecimalMin("0.0")
    @DecimalMax("1.0")
    private double maximumDeactivationRatio = 0.25;

    @AssertTrue(message = "Stop import coordinate bounds are invalid")
    public boolean isCoordinateBoundsValid() {
        return minLat >= -90.0
                && maxLat <= 90.0
                && minLat < maxLat
                && minLon >= -180.0
                && maxLon <= 180.0
                && minLon < maxLon;
    }
}
