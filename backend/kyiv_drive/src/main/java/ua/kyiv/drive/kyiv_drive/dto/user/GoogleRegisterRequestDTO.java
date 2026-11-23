package ua.kyiv.drive.kyiv_drive.dto.user;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import ua.kyiv.drive.kyiv_drive.entity.CurrentMode;
import ua.kyiv.drive.kyiv_drive.validation.InputValidation;

@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
public class GoogleRegisterRequestDTO {
    @NotBlank(message = "Google ID Token is missing")
    @Size(max = 4096, message = "Google ID Token exceeds maximum allowed length")
    private String idToken;

    @NotBlank(message = "Name cannot be empty")
    @Size(min = 2, max = 100, message = "Name must be 2–100 characters long")
    @Pattern(regexp = InputValidation.PERSON_NAME, message = "Name contains invalid characters")
    private String name;

    @Size(max = 2048, message = "Avatar URL exceeds maximum allowed length")
    private String avatarUrl;

    @NotNull(message = "Current mode is required")
    private CurrentMode currentMode;

    @Valid
    @NotNull(message = "Device context is required")
    private DeviceContextDTO device;

    public void setName(String name) {
        this.name = (name != null) ? name.strip() : null;
    }

    public void setAvatarUrl(String avatarUrl) {
        this.avatarUrl = (avatarUrl != null) ? avatarUrl.strip() : null;
    }
}
