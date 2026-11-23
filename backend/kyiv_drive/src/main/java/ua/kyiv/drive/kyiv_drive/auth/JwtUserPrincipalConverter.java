package ua.kyiv.drive.kyiv_drive.auth;

import org.springframework.core.convert.converter.Converter;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.AbstractOAuth2TokenAuthenticationToken;
import org.springframework.stereotype.Component;
import ua.kyiv.drive.kyiv_drive.entity.CurrentMode;
import ua.kyiv.drive.kyiv_drive.entity.UserRole;

import java.util.List;
import java.util.UUID;

@Component
public class JwtUserPrincipalConverter implements Converter<Jwt, AbstractOAuth2TokenAuthenticationToken<Jwt>> {

    @Override
    public AbstractOAuth2TokenAuthenticationToken<Jwt> convert(Jwt jwt) {
        UserRole role = UserRole.valueOf(jwt.getClaimAsString("role"));
        var authorities = List.of(new SimpleGrantedAuthority("ROLE_" + role.name()));
        UserPrincipal principal = new UserPrincipal(
                UUID.fromString(jwt.getSubject()),
                UUID.fromString(jwt.getClaimAsString("sid")),
                role,
                CurrentMode.valueOf(jwt.getClaimAsString("current_mode")),
                authorities
        );

        return new PrincipalJwtAuthenticationToken(jwt, principal, authorities);
    }

    private static final class PrincipalJwtAuthenticationToken extends AbstractOAuth2TokenAuthenticationToken<Jwt> {

        private final UserPrincipal principal;

        private PrincipalJwtAuthenticationToken(
                Jwt token,
                UserPrincipal principal,
                List<SimpleGrantedAuthority> authorities
        ) {
            super(token, principal, null, authorities);
            this.principal = principal;
            setAuthenticated(true);
        }

        @Override
        public Object getPrincipal() {
            return principal;
        }

        @Override
        public Object getCredentials() {
            return "";
        }

        @Override
        public java.util.Map<String, Object> getTokenAttributes() {
            return getToken().getClaims();
        }
    }
}
