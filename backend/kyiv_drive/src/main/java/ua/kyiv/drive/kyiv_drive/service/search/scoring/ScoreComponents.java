package ua.kyiv.drive.kyiv_drive.service.search.scoring;

/** Normalized criterion values, each in the inclusive range [0, 1]. */
public record ScoreComponents(double departure, double arrival, double walking, double weekdays, double price,
                              double duration) {
}
