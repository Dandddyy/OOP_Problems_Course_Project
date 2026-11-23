package ua.kyiv.drive.kyiv_drive.model.search;

import java.time.Instant;
import java.time.LocalDate;

public record SearchOccurrence(LocalDate requestedDate, LocalDate driverDepartureDate, Instant departureAt) {
}
