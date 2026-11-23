package ua.kyiv.drive.kyiv_drive.dto.user;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import ua.kyiv.drive.kyiv_drive.validation.InputValidation;

import java.util.Locale;

@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
public class VerifyCodeRequestDTO {
    @NotBlank(message = "Email cannot be empty")
    @Size(max = 255, message = "Email cannot exceed 255 characters")
    @Pattern(regexp = InputValidation.EMAIL, message = "Invalid email format")
    private String email;

    @NotBlank(message = "Code cannot be empty")
    @Pattern(regexp = "^\\d{6}$", message = "Code must be exactly 6 digits and contain only numbers")
    private String code;

    public void setEmail(String email) {
        this.email = (email != null) ? email.strip().toLowerCase(Locale.ROOT) : null;
    }

    public void setCode(String code) {
        this.code = (code != null) ? code.strip() : null;
    }
}
