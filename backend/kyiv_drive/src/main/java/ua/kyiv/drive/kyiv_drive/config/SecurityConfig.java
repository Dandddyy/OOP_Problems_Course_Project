package ua.kyiv.drive.kyiv_drive.config;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.security.autoconfigure.actuate.web.servlet.EndpointRequest;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.argon2.Argon2PasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.server.resource.web.authentication.BearerTokenAuthenticationFilter;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.access.intercept.AuthorizationFilter;
import org.springframework.security.web.servlet.util.matcher.PathPatternRequestMatcher;
import org.springframework.security.web.util.matcher.AndRequestMatcher;
import org.springframework.security.web.util.matcher.NegatedRequestMatcher;
import org.springframework.security.web.util.matcher.OrRequestMatcher;
import org.springframework.security.web.util.matcher.RequestMatcher;
import org.springframework.web.servlet.HandlerExceptionResolver;
import ua.kyiv.drive.kyiv_drive.auth.ApiRateLimitFilter;
import ua.kyiv.drive.kyiv_drive.auth.JwtUserPrincipalConverter;
import ua.kyiv.drive.kyiv_drive.auth.RestAuthenticationEntryPoint;
import ua.kyiv.drive.kyiv_drive.service.limit.RequestRateLimits;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    private static final int ARGON2_SALT_LENGTH = 16;
    private static final int ARGON2_HASH_LENGTH = 32;
    private static final int ARGON2_PARALLELISM = 1;
    private static final int ARGON2_MEMORY_KIB = 19 * 1024;
    private static final int ARGON2_ITERATIONS = 2;
    private static final PathPatternRequestMatcher.Builder PATHS = PathPatternRequestMatcher.withDefaults();
    private static final RequestMatcher PUBLIC_API = new OrRequestMatcher(
            PATHS.matcher("/api/user/login"),
            PATHS.matcher("/api/user/register"),
            PATHS.matcher("/api/user/google/**"),
            PATHS.matcher("/api/user/refresh"),
            PATHS.matcher("/api/user/send-code"),
            PATHS.matcher("/api/user/verify-code"),
            PATHS.matcher("/api/user/reset-password"),
            PATHS.matcher("/api/user/send-registration-code"));
    private static final RequestMatcher ACCOUNT_API = new AndRequestMatcher(
            PATHS.matcher("/api/**"), new NegatedRequestMatcher(PUBLIC_API));

    private final JwtUserPrincipalConverter jwtUserPrincipalConverter;
    private final RestAuthenticationEntryPoint authenticationEntryPoint;
    private final JwtDecoder accessJwtDecoder;

    public SecurityConfig(
            JwtUserPrincipalConverter jwtUserPrincipalConverter,
            RestAuthenticationEntryPoint authenticationEntryPoint,
            @Qualifier("accessJwtDecoder") JwtDecoder accessJwtDecoder
    ) {
        this.jwtUserPrincipalConverter = jwtUserPrincipalConverter;
        this.authenticationEntryPoint = authenticationEntryPoint;
        this.accessJwtDecoder = accessJwtDecoder;
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http, RequestRateLimits limits,
            @Qualifier("handlerExceptionResolver") HandlerExceptionResolver exceptions) {
        http
                .csrf(AbstractHttpConfigurer::disable)
                .cors(cors -> cors.configure(http))
                .authorizeHttpRequests(auth -> auth

                        .requestMatchers(PUBLIC_API).permitAll()

                        .requestMatchers(EndpointRequest.toAnyEndpoint()).hasRole("ADMIN")
                        .requestMatchers("/api/user/out", "/api/stop/import/**").hasRole("ADMIN")

                        .anyRequest().authenticated()
                )
                .sessionManagement(session -> session
                        .sessionCreationPolicy(SessionCreationPolicy.STATELESS)
                )
                .addFilterBefore(new ApiRateLimitFilter(PUBLIC_API, true, limits, exceptions),
                        BearerTokenAuthenticationFilter.class)
                .addFilterAfter(new ApiRateLimitFilter(ACCOUNT_API, false, limits, exceptions), AuthorizationFilter.class)
                .oauth2ResourceServer(oauth2 -> oauth2
                        .authenticationEntryPoint(authenticationEntryPoint)
                        .jwt(jwt -> jwt
                                .decoder(accessJwtDecoder)
                                .jwtAuthenticationConverter(jwtUserPrincipalConverter)
                        )
                );

        return http.build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new Argon2PasswordEncoder(
                ARGON2_SALT_LENGTH,
                ARGON2_HASH_LENGTH,
                ARGON2_PARALLELISM,
                ARGON2_MEMORY_KIB,
                ARGON2_ITERATIONS
        );
    }
}
