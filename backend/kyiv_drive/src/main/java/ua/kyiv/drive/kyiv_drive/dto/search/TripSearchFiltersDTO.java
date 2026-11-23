package ua.kyiv.drive.kyiv_drive.dto.search;

import com.fasterxml.jackson.annotation.JsonAnySetter;
import jakarta.validation.constraints.Positive;
import lombok.Getter;
import lombok.Setter;

/** Bounds can be narrowed within the original candidate-selection envelope. */
@Getter
@Setter
public class TripSearchFiltersDTO {
    @Positive(message = "Maximum walking distance must be positive")
    private Integer maxWalkMeters;
    @Positive(message = "Maximum walking duration must be positive")
    private Integer maxWalkSeconds;
    @Positive(message = "Maximum total walking duration must be positive")
    private Integer maxTotalWalkSeconds;
    @Positive(message = "Time deviation must be positive")
    private Integer timeDeviationMinutes;

    @JsonAnySetter
    public void rejectUnknownField(String name, Object value) {
        throw new IllegalArgumentException("Unsupported search filter field");
    }
}
