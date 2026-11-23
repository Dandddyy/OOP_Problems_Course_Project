package ua.kyiv.drive.kyiv_drive.dto.template;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.UUID;

@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
public class TemplateStopResponseDTO {
    private UUID id;
    private UUID templateId;
    private UUID stopId;
    private Short sequenceNumber;
    private Integer cumulativeDurationSeconds;
    private Integer cumulativeDistanceMeters;
    private Boolean isEnabled;
    private Boolean isAvailable;
    private String name;
    private Double lat;
    private Double lon;
}
