package ua.kyiv.drive.kyiv_drive.config;

import jakarta.validation.constraints.Min;
import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;
import org.springframework.validation.annotation.Validated;

@Getter
@Setter
@Validated
@Component
@ConfigurationProperties("app.trip-search.admission")
public class TripSearchAdmissionProperties {
    @Min(1) private int newSearchesPerMinute = 6;
    @Min(1) private int newSearchesPerHour = 60;
    @Min(1) private int recalculationsPerMinute = 20;
}
