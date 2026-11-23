package ua.kyiv.drive.kyiv_drive.dto.user;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
public class GoogleLoginRequestDTO {
    @NotBlank(message = "Google ID Token is missing")
    @Size(max = 4096, message = "Google ID Token exceeds maximum allowed length")
    private String idToken;

    @Size(max = 2048, message = "Avatar URL exceeds maximum allowed length")
    private String avatarUrl;

    @Valid
    @NotNull(message = "Device context is required")
    private DeviceContextDTO device;

    public void setAvatarUrl(String avatarUrl) {
        this.avatarUrl = (avatarUrl != null) ? avatarUrl.strip() : null;
    }
}
