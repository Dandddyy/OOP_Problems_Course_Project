package ua.kyiv.drive.kyiv_drive.auth;

import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jwt.Jwt;

import java.util.Set;

public class JwtHeaderValidator implements OAuth2TokenValidator<Jwt> {

    private static final OAuth2Error INVALID_HEADER = new OAuth2Error(
            "invalid_token",
            "The JWT type or key id is not accepted",
            null
    );

    private final String expectedType;
    private final Set<String> acceptedKeyIds;

    public JwtHeaderValidator(String expectedType, Set<String> acceptedKeyIds) {
        this.expectedType = expectedType;
        this.acceptedKeyIds = Set.copyOf(acceptedKeyIds);
    }

    @Override
    public OAuth2TokenValidatorResult validate(Jwt token) {
        boolean valid = expectedType.equals(token.getHeaders().get("typ"))
                && acceptedKeyIds.contains(token.getHeaders().get("kid"));
        return valid
                ? OAuth2TokenValidatorResult.success()
                : OAuth2TokenValidatorResult.failure(INVALID_HEADER);
    }
}
