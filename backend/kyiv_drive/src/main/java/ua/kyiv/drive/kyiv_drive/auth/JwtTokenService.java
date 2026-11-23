package ua.kyiv.drive.kyiv_drive.auth;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.security.oauth2.jose.jws.SignatureAlgorithm;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.security.oauth2.jwt.JwtException;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.stereotype.Service;
import ua.kyiv.drive.kyiv_drive.config.JwtConfiguration;
import ua.kyiv.drive.kyiv_drive.config.JwtProperties;
import ua.kyiv.drive.kyiv_drive.entity.CurrentMode;
import ua.kyiv.drive.kyiv_drive.entity.UserRole;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Service
public class JwtTokenService {

    private final JwtEncoder accessEncoder;
    private final JwtEncoder refreshEncoder;
    private final JwtDecoder refreshDecoder;
    private final JwtProperties properties;
    private final Clock clock;

    public JwtTokenService(
            @Qualifier("accessJwtEncoder") JwtEncoder accessEncoder,
            @Qualifier("refreshJwtEncoder") JwtEncoder refreshEncoder,
            @Qualifier("refreshJwtDecoder") JwtDecoder refreshDecoder,
            JwtProperties properties,
            Clock clock
    ) {
        this.accessEncoder = accessEncoder;
        this.refreshEncoder = refreshEncoder;
        this.refreshDecoder = refreshDecoder;
        this.properties = properties;
        this.clock = clock;
    }

    public IssuedAccessToken issueAccessToken(
            UUID userId,
            UUID sessionId,
            UserRole role,
            CurrentMode currentMode
    ) {
        Instant now = clock.instant().truncatedTo(ChronoUnit.SECONDS);
        Instant expiresAt = now.plus(properties.getAccessTtl());
        JwtClaimsSet claims = JwtClaimsSet.builder()
                .issuer(properties.getIssuer())
                .audience(List.of(properties.getAccessAudience()))
                .subject(userId.toString())
                .expiresAt(expiresAt)
                .claim("sid", sessionId.toString())
                .claim("role", role.name())
                .claim("current_mode", currentMode.name())
                .build();

        String token = accessEncoder.encode(JwtEncoderParameters.from(
                header(JwtConfiguration.ACCESS_TOKEN_TYPE, properties.getAccess().getActiveKeyId()),
                claims
        )).getTokenValue();
        return new IssuedAccessToken(token, expiresAt);
    }

    public String generateRefreshToken(RefreshTokenClaims token) {
        JwtClaimsSet claims = JwtClaimsSet.builder()
                .issuer(properties.getIssuer())
                .audience(List.of(properties.getRefreshAudience()))
                .subject(token.userId().toString())
                .expiresAt(token.expiresAt())
                .claim("sid", token.sessionId().toString())
                .claim("generation", token.generation())
                .build();

        return refreshEncoder.encode(JwtEncoderParameters.from(
                header(JwtConfiguration.REFRESH_TOKEN_TYPE, properties.getRefresh().getActiveKeyId()),
                claims
        )).getTokenValue();
    }

    public Optional<RefreshTokenClaims> validateRefreshToken(String token) {
        try {
            Jwt jwt = refreshDecoder.decode(token);
            Number generation = jwt.getClaim("generation");
            return Optional.of(new RefreshTokenClaims(
                    UUID.fromString(jwt.getSubject()),
                    UUID.fromString(jwt.getClaimAsString("sid")),
                    generation.longValue(),
                    jwt.getExpiresAt()
            ));
        } catch (JwtException | IllegalArgumentException | NullPointerException | ClassCastException e) {
            return Optional.empty();
        }
    }

    private JwsHeader header(String type, String keyId) {
        return JwsHeader.with(SignatureAlgorithm.RS256)
                .type(type)
                .keyId(keyId)
                .build();
    }

    public record IssuedAccessToken(String token, Instant expiresAt) {
    }
}
