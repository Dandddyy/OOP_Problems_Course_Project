package ua.kyiv.drive.kyiv_drive.config;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.NotBlank;
import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;
import org.springframework.validation.annotation.Validated;

import java.util.List;

@Getter
@Setter
@Validated
@Component
@ConfigurationProperties(prefix = "app.trip-search")
public class TripSearchProperties {
    @Min(1) private int defaultWalkMeters = 2000;
    @Min(1) private int maxAllowedWalkMeters = 5000;
    @Min(1) private int defaultWalkSeconds = 1800;
    @Min(1) private int maxAllowedWalkSeconds = 3600;
    @Min(1) private int defaultTotalWalkSeconds = 2700;
    @Min(1) private int maxAllowedTotalWalkSeconds = 5400;
    @Min(1) private int defaultDeviationMinutes = 60;
    @Min(1) private int maxDeviationMinutes = 180;
    @Min(1) private int defaultPageSize = 20;
    @Min(1) private int maxPageSize = 50;
    @Min(1) @Max(500) private int maxRestoreItems = 200;
    @Min(7) private int horizonDays = 14;
    @DecimalMin("0.01") @DecimalMax("0.99") private double mainPriorityWeight = 0.4;
    private List<Double> regularRankWeights = List.of(0.4, 0.25, 0.17, 0.11, 0.07);
    private List<Double> oneTimeRankWeights = List.of(0.4, 0.28, 0.19, 0.13);
    @Min(1) private int departureEarlyScaleSeconds = 1800;
    @Min(1) private int departureLateScaleSeconds = 3600;
    @Min(1) private int arrivalLateScaleSeconds = 1800;
    @Min(1) private int walkingScaleSeconds = 2700;
    @Min(1) private int pairDurationScaleSeconds = 14_400;
    @Min(1) private int pairFareScaleUah = 50;
    @DecimalMin("0.01") @DecimalMax("0.99") private double rankingDurationWeight = 0.15;
    @Min(1) private int rankingDurationScaleSeconds = 3600;
    @NotBlank private String formulaVersion = "v3";

    @AssertTrue(message = "Search limits and scoring weights must be consistent")
    public boolean isConfigurationValid() {
        return defaultWalkMeters <= maxAllowedWalkMeters && defaultWalkSeconds <= maxAllowedWalkSeconds
                && defaultTotalWalkSeconds <= maxAllowedTotalWalkSeconds
                && defaultDeviationMinutes <= maxDeviationMinutes && defaultPageSize <= maxPageSize
                && maxPageSize <= maxRestoreItems
                && horizonDays <= 28 && weightsValid(regularRankWeights, 5) && weightsValid(oneTimeRankWeights, 4);
    }

    private boolean weightsValid(List<Double> weights, int size) {
        return weights != null && weights.size() == size && weights.stream()
                .allMatch(value -> value != null && Double.isFinite(value) && value > 0);
    }
}
