package ua.kyiv.drive.kyiv_drive.service.search;

import java.util.UUID;

/** Deduplicates retries while the session's published search remains available. */
public record SearchRequestIdentity(UUID requestId, String fingerprint, String searchId) { }
