package ua.kyiv.drive.kyiv_drive.dto.user;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import ua.kyiv.drive.kyiv_drive.entity.CurrentMode;
import ua.kyiv.drive.kyiv_drive.entity.UserRole;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Locale;
import java.util.UUID;

@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
public class UserDTO {
    private UUID id;
    private String email;
    private String name;

    @JsonProperty(access = JsonProperty.Access.WRITE_ONLY)
    private String password;

    private String avatarUrl;
    private LocalDate lastActivity;
    private LocalDate created;
    private Boolean isActive;
    private UserRole role;
    private BigDecimal rating;
    private Integer ratingCount;
    private CurrentMode currentMode;
    private Boolean tutorialCompleted;
    private String bio;

    public void setName(String name) {
        this.name = (name != null) ? name.strip() : null;
    }

    public void setEmail(String email) {
        this.email = (email != null) ? email.strip().toLowerCase(Locale.ROOT) : null;
    }

    public void setPassword(String password) {
        this.password = password;
    }

    public void setAvatarUrl(String avatarUrl) {
        this.avatarUrl = (avatarUrl != null) ? avatarUrl.strip() : null;
    }

    public void setBio(String bio) {
        this.bio = (bio != null) ? bio.strip() : null;
    }
}
