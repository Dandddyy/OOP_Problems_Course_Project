package ua.kyiv.drive.kyiv_drive.service;

import java.time.Instant;
import java.util.UUID;

public record TripPublicationResult(UUID tripId, boolean created, Instant confirmationExpiresAt) {
}
