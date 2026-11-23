package ua.kyiv.drive.kyiv_drive.auth;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.servlet.util.matcher.PathPatternRequestMatcher;
import org.springframework.security.web.util.matcher.OrRequestMatcher;
import org.springframework.security.web.util.matcher.RequestMatcher;
import org.springframework.web.filter.OncePerRequestFilter;
import org.springframework.web.servlet.HandlerExceptionResolver;
import ua.kyiv.drive.kyiv_drive.exception.RateLimitException;
import ua.kyiv.drive.kyiv_drive.service.limit.RequestRateLimits;

import java.io.IOException;
import java.util.Locale;

@RequiredArgsConstructor
public class ApiRateLimitFilter extends OncePerRequestFilter {
    private static final PathPatternRequestMatcher.Builder PATHS = PathPatternRequestMatcher.withDefaults();
    private static final RequestMatcher AUTH_OPERATIONS = new OrRequestMatcher(
            PATHS.matcher(HttpMethod.POST, "/api/user/login"),
            PATHS.matcher(HttpMethod.POST, "/api/user/register"),
            PATHS.matcher(HttpMethod.POST, "/api/user/google/login"),
            PATHS.matcher(HttpMethod.POST, "/api/user/google/register"));
    private static final RequestMatcher OTP_SEND = new OrRequestMatcher(
            PATHS.matcher(HttpMethod.POST, "/api/user/send-code"),
            PATHS.matcher(HttpMethod.POST, "/api/user/send-registration-code"));

    private final RequestMatcher routes;
    private final boolean publicApi;
    private final RequestRateLimits limits;
    private final HandlerExceptionResolver exceptions;

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return !routes.matches(request);
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        try {
            if (publicApi) {
                String ip = request.getRemoteAddr();
                limits.publicApi(ip);
                if (AUTH_OPERATIONS.matches(request)) limits.loginIp(ip);
                if (OTP_SEND.matches(request)) limits.otpSendIp(ip);
            } else {
                var authentication = SecurityContextHolder.getContext().getAuthentication();
                if (authentication != null && authentication.getPrincipal() instanceof UserPrincipal principal) {
                    limits.account(principal.getId());
                }
            }
        } catch (RateLimitException failure) {
            response.setStatus(failure.getStatus().value());
            var previousLocale = LocaleContextHolder.getLocaleContext();
            try {
                LocaleContextHolder.setLocale(request.getHeader(HttpHeaders.ACCEPT_LANGUAGE) == null
                        ? Locale.ENGLISH : request.getLocale());
                exceptions.resolveException(request, response, null, failure);
            } finally {
                LocaleContextHolder.setLocaleContext(previousLocale);
            }
            return;
        }
        chain.doFilter(request, response);
    }
}
