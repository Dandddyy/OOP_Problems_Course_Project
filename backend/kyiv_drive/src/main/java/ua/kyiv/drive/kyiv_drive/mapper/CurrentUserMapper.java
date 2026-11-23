package ua.kyiv.drive.kyiv_drive.mapper;

import org.springframework.stereotype.Component;
import ua.kyiv.drive.kyiv_drive.dto.user.CurrentUserDTO;
import ua.kyiv.drive.kyiv_drive.entity.User;

@Component
public class CurrentUserMapper {

    public CurrentUserDTO toDTO(User user) {
        return new CurrentUserDTO(
                user.getId(),
                user.getEmail(),
                user.getName(),
                user.getAvatarUrl(),
                user.getBio(),
                user.getTutorialCompleted(),
                user.getRole()
        );
    }
}
