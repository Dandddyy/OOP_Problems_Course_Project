package ua.kyiv.drive.kyiv_drive.dto.template;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import ua.kyiv.drive.kyiv_drive.entity.TripWaypoint;

import java.time.ZonedDateTime;
import java.util.List;
import java.util.UUID;

@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
public class TemplateResponseDTO {
    private UUID id;
    private UUID userId;
    private String startShortAddress;
    private String startSubtitle;
    private String endShortAddress;
    private String endSubtitle;
    private Double startLat;
    private Double startLon;
    private Double endLat;
    private Double endLon;
    private List<TripWaypoint> waypoints;
    private String routePolyline;
    private Integer totalDurationSeconds;
    private Integer totalDistanceMeters;
    private Boolean isDriver;
    private Long stopsCatalogVersion;
    private ZonedDateTime createdAt;

    public void setStartShortAddress(String startShortAddress) {
        this.startShortAddress = (startShortAddress != null) ? startShortAddress.strip() : null;
    }

    public void setStartSubtitle(String startSubtitle) {
        this.startSubtitle = (startSubtitle != null) ? startSubtitle.strip() : null;
    }

    public void setEndShortAddress(String endShortAddress) {
        this.endShortAddress = (endShortAddress != null) ? endShortAddress.strip() : null;
    }

    public void setEndSubtitle(String endSubtitle) {
        this.endSubtitle = (endSubtitle != null) ? endSubtitle.strip() : null;
    }
}
