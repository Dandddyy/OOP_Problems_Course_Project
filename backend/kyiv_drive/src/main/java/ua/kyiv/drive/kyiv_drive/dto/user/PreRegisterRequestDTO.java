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
public class PreRegisterRequestDTO {
    @NotBlank(message = "Email cannot be empty")
    @Size(max = 255, message = "Email cannot exceed 255 characters")
    @Pattern(regexp = InputValidation.EMAIL, message = "Invalid email format")
    private String email;

    @NotBlank(message = "Name cannot be empty")
    @Size(min = 2, max = 100, message = "Name must be 2–100 characters long")
    @Pattern(regexp = InputValidation.PERSON_NAME, message = "Name contains invalid characters")
    private String name;

    @NotBlank(message = "Password cannot be empty")
    @Size(min = 6, max = 100, message = "Password must be 6–100 characters long")
    @Pattern(regexp = InputValidation.PASSWORD, message = "Password must contain uppercase, lowercase, and a digit")
    private String password;

    public void setEmail(String email) {
        this.email = (email != null) ? email.strip().toLowerCase(Locale.ROOT) : null;
    }

    public void setName(String name) {
        this.name = (name != null) ? name.strip() : null;
    }

    public void setPassword(String password) {
        this.password = password;
    }
}
