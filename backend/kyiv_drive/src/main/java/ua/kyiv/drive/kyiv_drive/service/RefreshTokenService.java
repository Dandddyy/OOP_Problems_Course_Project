package ua.kyiv.drive.kyiv_drive.service;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import ua.kyiv.drive.kyiv_drive.auth.JwtTokenService;
import ua.kyiv.drive.kyiv_drive.auth.RefreshTokenClaims;
import ua.kyiv.drive.kyiv_drive.dto.user.AuthResponseDTO;
import ua.kyiv.drive.kyiv_drive.dto.user.DeviceContextDTO;
import ua.kyiv.drive.kyiv_drive.exception.InvalidRefreshTokenException;

@Service
@RequiredArgsConstructor
public class RefreshTokenService {

    private final JwtTokenService jwtTokenService;
    private final RefreshRotationTransaction rotationTransaction;

    public AuthResponseDTO refresh(String rawToken, DeviceContextDTO device) {
        RefreshTokenClaims claims = jwtTokenService.validateRefreshToken(rawToken)
                .orElseThrow(InvalidRefreshTokenException::new);
        RefreshRotationResult result = rotationTransaction.rotate(claims, rawToken, device);
        if (!result.isAccepted()) {
            throw new InvalidRefreshTokenException();
        }
        return result.response();
    }
}
