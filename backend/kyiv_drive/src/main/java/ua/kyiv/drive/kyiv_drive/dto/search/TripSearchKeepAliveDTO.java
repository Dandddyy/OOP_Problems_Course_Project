package ua.kyiv.drive.kyiv_drive.dto.search;

import java.time.Instant;

public record TripSearchKeepAliveDTO(String searchId, Instant expiresAt) {
}
