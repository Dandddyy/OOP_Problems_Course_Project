package ua.kyiv.drive.kyiv_drive.config;

import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.jwk.JWK;
import com.nimbusds.jose.jwk.JWKSet;
import com.nimbusds.jose.jwk.KeyUse;
import com.nimbusds.jose.jwk.RSAKey;
import com.nimbusds.jose.jwk.source.ImmutableJWKSet;
import com.nimbusds.jose.jwk.source.JWKSource;
import com.nimbusds.jose.proc.SecurityContext;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.Resource;
import org.springframework.security.converter.RsaKeyConverters;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jose.jws.SignatureAlgorithm;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtIssuerValidator;
import org.springframework.security.oauth2.jwt.JwtTimestampValidator;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;
import ua.kyiv.drive.kyiv_drive.auth.JwtHeaderValidator;
import ua.kyiv.drive.kyiv_drive.entity.CurrentMode;
import ua.kyiv.drive.kyiv_drive.entity.UserRole;

import java.io.IOException;
import java.io.InputStream;
import java.security.MessageDigest;
import java.security.interfaces.RSAPrivateKey;
import java.security.interfaces.RSAPublicKey;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

@Configuration
public class JwtConfiguration {

    public static final String ACCESS_TOKEN_TYPE = "at+jwt";
    public static final String REFRESH_TOKEN_TYPE = "rt+jwt";

    private static final OAuth2Error INVALID_ACCESS_CLAIMS = new OAuth2Error(
            "invalid_token",
            "Required access token claims are missing or invalid",
            null
    );
    private static final OAuth2Error INVALID_REFRESH_CLAIMS = new OAuth2Error(
            "invalid_token",
            "Required refresh token claims are missing or invalid",
            null
    );

    @Bean("accessKeyRing")
    public JwtKeyRing accessKeyRing(JwtProperties properties) {
        return loadKeyRing("access", properties.getAccess());
    }

    @Bean("refreshKeyRing")
    public JwtKeyRing refreshKeyRing(
            JwtProperties properties,
            @Qualifier("accessKeyRing") JwtKeyRing accessKeyRing
    ) {
        JwtKeyRing refreshKeyRing = loadKeyRing("refresh", properties.getRefresh());
        ensureNoSharedKeys(accessKeyRing, refreshKeyRing);
        return refreshKeyRing;
    }

    @Bean("accessJwtEncoder")
    public JwtEncoder accessJwtEncoder(
            @Qualifier("accessKeyRing") JwtKeyRing keyRing
    ) {
        return encoder(keyRing);
    }

    @Bean("refreshJwtEncoder")
    public JwtEncoder refreshJwtEncoder(
            @Qualifier("refreshKeyRing") JwtKeyRing keyRing,
            @Qualifier("accessKeyRing") JwtKeyRing accessKeyRing
    ) {
        ensureNoSharedKeys(accessKeyRing, keyRing);
        return encoder(keyRing);
    }

    @Bean("accessJwtDecoder")
    public JwtDecoder accessJwtDecoder(
            @Qualifier("accessKeyRing") JwtKeyRing keyRing,
            JwtProperties properties
    ) {
        NimbusJwtDecoder decoder = decoder(keyRing);
        decoder.setJwtValidator(validators(
                properties,
                properties.getAccessAudience(),
                ACCESS_TOKEN_TYPE,
                keyRing.keyIds(),
                this::hasValidAccessClaims
        ));
        return decoder;
    }

    @Bean("refreshJwtDecoder")
    public JwtDecoder refreshJwtDecoder(
            @Qualifier("refreshKeyRing") JwtKeyRing keyRing,
            JwtProperties properties
    ) {
        NimbusJwtDecoder decoder = decoder(keyRing);
        decoder.setJwtValidator(validators(
                properties,
                properties.getRefreshAudience(),
                REFRESH_TOKEN_TYPE,
                keyRing.keyIds(),
                this::hasValidRefreshClaims
        ));
        return decoder;
    }

    private JwtEncoder encoder(JwtKeyRing keyRing) {
        JwtKey activeKey = keyRing.activeKey();
        return NimbusJwtEncoder.withKeyPair(
                        activeKey.publicKey(),
                        activeKey.privateKey()
                )
                .algorithm(SignatureAlgorithm.RS256)
                .jwkPostProcessor(builder -> builder.keyID(activeKey.id()))
                .build();
    }

    private NimbusJwtDecoder decoder(JwtKeyRing keyRing) {
        List<JWK> publicKeys = keyRing.keys().values().stream()
                .map(key -> new RSAKey.Builder(key.publicKey())
                        .keyID(key.id())
                        .keyUse(KeyUse.SIGNATURE)
                        .algorithm(JWSAlgorithm.RS256)
                        .build())
                .map(JWK.class::cast)
                .toList();
        JWKSource<SecurityContext> jwkSource = new ImmutableJWKSet<>(new JWKSet(publicKeys));
        return NimbusJwtDecoder.withJwkSource(jwkSource)
                .jwsAlgorithm(SignatureAlgorithm.RS256)
                .build();
    }

    private OAuth2TokenValidator<Jwt> validators(
            JwtProperties properties,
            String audience,
            String tokenType,
            Set<String> keyIds,
            OAuth2TokenValidator<Jwt> claimValidator
    ) {
        JwtTimestampValidator timestampValidator = new JwtTimestampValidator(properties.getClockSkew());
        timestampValidator.setAllowEmptyExpiryClaim(false);
        return new DelegatingOAuth2TokenValidator<>(
                timestampValidator,
                new JwtIssuerValidator(properties.getIssuer()),
                new JwtHeaderValidator(tokenType, keyIds),
                new AudienceValidator(audience),
                claimValidator
        );
    }

    private OAuth2TokenValidatorResult hasValidAccessClaims(Jwt jwt) {
        try {
            UUID.fromString(jwt.getSubject());
            UUID.fromString(jwt.getClaimAsString("sid"));
            UserRole.valueOf(jwt.getClaimAsString("role"));
            CurrentMode.valueOf(jwt.getClaimAsString("current_mode"));
            return OAuth2TokenValidatorResult.success();
        } catch (IllegalArgumentException | NullPointerException e) {
            return OAuth2TokenValidatorResult.failure(INVALID_ACCESS_CLAIMS);
        }
    }

    private OAuth2TokenValidatorResult hasValidRefreshClaims(Jwt jwt) {
        try {
            UUID.fromString(jwt.getSubject());
            UUID.fromString(jwt.getClaimAsString("sid"));
            Number generation = jwt.getClaim("generation");
            if (generation == null || generation.longValue() < 1) {
                return OAuth2TokenValidatorResult.failure(INVALID_REFRESH_CLAIMS);
            }
            return OAuth2TokenValidatorResult.success();
        } catch (IllegalArgumentException | NullPointerException | ClassCastException e) {
            return OAuth2TokenValidatorResult.failure(INVALID_REFRESH_CLAIMS);
        }
    }

    private JwtKeyRing loadKeyRing(
            String tokenKind,
            JwtProperties.KeyRing configuredKeyRing
    ) {
        if (configuredKeyRing == null || configuredKeyRing.getActiveKeyId() == null
                || configuredKeyRing.getActiveKeyId().isBlank()) {
            throw new IllegalStateException("An active key id is required for " + tokenKind + " JWTs");
        }

        List<JwtProperties.KeyDefinition> definitions = configuredKeyRing.getKeys();
        if (definitions == null || definitions.isEmpty()) {
            throw new IllegalStateException(
                    "At least one external RSA key is required for " + tokenKind + " JWTs"
            );
        }

        Map<String, JwtKey> keys = new LinkedHashMap<>();
        for (JwtProperties.KeyDefinition definition : definitions) {
            JwtKey key = loadKey(tokenKind, definition);
            if (keys.putIfAbsent(key.id(), key) != null) {
                throw new IllegalStateException("Duplicate " + tokenKind + " JWT key id: " + key.id());
            }
        }

        JwtKeyRing keyRing = new JwtKeyRing(configuredKeyRing.getActiveKeyId(), keys);
        keyRing.activeKey();
        return keyRing;
    }

    private JwtKey loadKey(String tokenKind, JwtProperties.KeyDefinition definition) {
        if (definition == null || definition.getId() == null || definition.getId().isBlank()) {
            throw new IllegalStateException("Every " + tokenKind + " JWT key requires a non-blank id");
        }
        if (definition.getPublicKeyLocation() == null) {
            throw new IllegalStateException("A public key is required for " + tokenKind + " JWT key " + definition.getId());
        }

        try (InputStream publicKeyInput = definition.getPublicKeyLocation().getInputStream()) {
            RSAPublicKey publicKey = RsaKeyConverters.x509().convert(publicKeyInput);
            if (publicKey == null) {
                throw new IllegalStateException("Could not decode public RSA key for " + tokenKind + " JWT key " + definition.getId());
            }
            if (publicKey.getModulus().bitLength() < 2048) {
                throw new IllegalStateException("RSA keys for " + tokenKind + " JWTs must be at least 2048 bits");
            }

            RSAPrivateKey privateKey = null;
            Resource privateKeyResource = definition.getPrivateKeyLocation();
            if (privateKeyResource != null) {
                try (InputStream privateKeyInput = privateKeyResource.getInputStream()) {
                    privateKey = RsaKeyConverters.pkcs8().convert(privateKeyInput);
                }
                if (privateKey == null || privateKey.getModulus().bitLength() < 2048) {
                    throw new IllegalStateException("Could not decode a valid private RSA key for " + tokenKind + " JWT key " + definition.getId());
                }
                if (!publicKey.getModulus().equals(privateKey.getModulus())) {
                    throw new IllegalStateException("Public and private RSA keys do not match for " + tokenKind + " JWT key " + definition.getId());
                }
            }

            return new JwtKey(definition.getId(), publicKey, privateKey);
        } catch (IOException | IllegalArgumentException e) {
            throw new IllegalStateException("Could not load RSA key material for " + tokenKind + " JWT key " + definition.getId(), e);
        }
    }

    private void ensureNoSharedKeys(JwtKeyRing accessKeyRing, JwtKeyRing refreshKeyRing) {
        boolean sharedKey = accessKeyRing.keys().values().stream()
                .anyMatch(accessKey -> refreshKeyRing.keys().values().stream()
                        .anyMatch(refreshKey -> MessageDigest.isEqual(
                                accessKey.publicKey().getEncoded(),
                                refreshKey.publicKey().getEncoded()
                        )));
        if (sharedKey) {
            throw new IllegalStateException("Access and refresh JWTs must use different RSA key pairs");
        }
    }

    public record JwtKey(String id, RSAPublicKey publicKey, RSAPrivateKey privateKey) {
    }

    public record JwtKeyRing(String activeKeyId, Map<String, JwtKey> keys) {

        public JwtKeyRing {
            keys = Map.copyOf(keys);
        }

        public JwtKey activeKey() {
            JwtKey activeKey = keys.get(activeKeyId);
            if (activeKey == null) {
                throw new IllegalStateException("Active JWT key is not present in the configured key ring: " + activeKeyId);
            }
            if (activeKey.privateKey() == null) {
                throw new IllegalStateException("Active JWT key requires a private key: " + activeKeyId);
            }
            return activeKey;
        }

        public Set<String> keyIds() {
            return keys.keySet();
        }
    }

    private record AudienceValidator(String audience) implements OAuth2TokenValidator<Jwt> {

        private static final OAuth2Error INVALID_AUDIENCE = new OAuth2Error(
                "invalid_token",
                "The JWT audience is not accepted",
                null
        );

        @Override
        public OAuth2TokenValidatorResult validate(Jwt token) {
            return token.getAudience().contains(audience)
                    ? OAuth2TokenValidatorResult.success()
                    : OAuth2TokenValidatorResult.failure(INVALID_AUDIENCE);
        }
    }
}
