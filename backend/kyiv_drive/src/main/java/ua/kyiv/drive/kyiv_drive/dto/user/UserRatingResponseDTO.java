package ua.kyiv.drive.kyiv_drive.dto.user;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import java.math.BigDecimal;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class UserRatingResponseDTO {
    private String name;
    private String avatarUrl;
    private BigDecimal rating;
    private Integer ratingCount;
}
