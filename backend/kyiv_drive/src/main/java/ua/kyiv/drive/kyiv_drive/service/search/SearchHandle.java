package ua.kyiv.drive.kyiv_drive.service.search;

import ua.kyiv.drive.kyiv_drive.model.search.SearchSort;

import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.UUID;

/** Opaque public reference; ownership is always checked against the authenticated session. */
public record SearchHandle(UUID contextId, UUID variantId, SearchSort sort) {
    public String encode() {
        return Base64.getUrlEncoder().withoutPadding().encodeToString(
                (contextId + ":" + variantId + ":" + sort).getBytes(StandardCharsets.UTF_8));
    }

    public static SearchHandle parse(String value) {
        try {
            if (value == null || value.length() > 160) throw SearchSnapshotStore.expired();
            String[] parts = new String(Base64.getUrlDecoder().decode(value), StandardCharsets.UTF_8).split(":", -1);
            if (parts.length != 3) throw SearchSnapshotStore.expired();
            SearchHandle handle = new SearchHandle(UUID.fromString(parts[0]), UUID.fromString(parts[1]),
                    SearchSort.valueOf(parts[2]));
            if (!handle.encode().equals(value)) throw SearchSnapshotStore.expired();
            return handle;
        } catch (IllegalArgumentException e) {
            throw SearchSnapshotStore.expired();
        }
    }
}
