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
import ua.kyiv.drive.kyiv_drive.validation.InputValidation;

@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
public class ResetPasswordRequestDTO {
    @NotBlank(message = "Password reset token is required")
    @Size(max = 128, message = "Password reset token is invalid")
    private String passwordResetToken;

    @NotBlank(message = "Password cannot be empty")
    @Size(min = 6, max = 100, message = "Password must be 6–100 characters long")
    @Pattern(regexp = InputValidation.PASSWORD, message = "Password must contain uppercase, lowercase, and a digit")
    private String newPassword;

    @Valid
    @NotNull(message = "Device context is required")
    private DeviceContextDTO device;

}
