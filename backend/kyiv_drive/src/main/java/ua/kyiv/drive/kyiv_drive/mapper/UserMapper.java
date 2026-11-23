package ua.kyiv.drive.kyiv_drive.mapper;

import ua.kyiv.drive.kyiv_drive.dto.user.UserDTO;
import ua.kyiv.drive.kyiv_drive.entity.User;
import org.mapstruct.Mapper;

@Mapper(componentModel = "spring")
public interface UserMapper {
    UserDTO toDTO(User user);

    User toEntity(UserDTO userDTO);
}
