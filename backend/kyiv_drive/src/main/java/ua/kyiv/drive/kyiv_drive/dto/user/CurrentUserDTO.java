package ua.kyiv.drive.kyiv_drive.dto.user;

import ua.kyiv.drive.kyiv_drive.entity.UserRole;

import java.util.UUID;

public record CurrentUserDTO(
        UUID id,
        String email,
        String name,
        String avatarUrl,
        String bio,
        Boolean tutorialCompleted,
        UserRole role
) {
}
