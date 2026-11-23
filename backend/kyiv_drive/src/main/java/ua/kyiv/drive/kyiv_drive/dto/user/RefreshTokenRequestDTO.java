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
public class RefreshTokenRequestDTO {
    @NotBlank(message = "Refresh token is missing")
    @Size(max = 2048, message = "Refresh token exceeds maximum allowed length")
    private String refreshToken;

    @Valid
    @NotNull(message = "Device context is required")
    private DeviceContextDTO device;
}
