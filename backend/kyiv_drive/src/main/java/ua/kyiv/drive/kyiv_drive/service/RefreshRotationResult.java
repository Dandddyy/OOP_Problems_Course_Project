package ua.kyiv.drive.kyiv_drive.service;

import ua.kyiv.drive.kyiv_drive.dto.user.AuthResponseDTO;

record RefreshRotationResult(AuthResponseDTO response) {

    static RefreshRotationResult accepted(AuthResponseDTO response) {
        return new RefreshRotationResult(response);
    }

    static RefreshRotationResult rejected() {
        return new RefreshRotationResult(null);
    }

    boolean isAccepted() {
        return response != null;
    }
}
