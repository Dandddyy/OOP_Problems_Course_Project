package ua.kyiv.drive.kyiv_drive.dto.user;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.Locale;

@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
public class LoginRequestDTO {
    @NotBlank(message = "Email cannot be empty")
    @Size(max = 255, message = "Email cannot exceed 255 characters")
    private String email;

    @NotBlank(message = "Password cannot be empty")
    @Size(max = 100, message = "Password cannot exceed 100 characters")
    private String password;

    @Valid
    @NotNull(message = "Device context is required")
    private DeviceContextDTO device;

    public void setEmail(String email) {
        this.email = (email != null) ? email.strip().toLowerCase(Locale.ROOT) : null;
    }

    public void setPassword(String password) {
        this.password = password;
    }
}
