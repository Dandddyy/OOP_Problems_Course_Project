package ua.kyiv.drive.kyiv_drive.config;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpMethod;
import org.springframework.security.web.servlet.util.matcher.PathPatternRequestMatcher;
import org.springframework.security.web.util.matcher.OrRequestMatcher;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import ua.kyiv.drive.kyiv_drive.service.execution.OperationProfile;

import java.io.IOException;

@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 10)
@RequiredArgsConstructor
public class OperationDeadlineFilter extends OncePerRequestFilter {
    private static final PathPatternRequestMatcher.Builder PATHS = PathPatternRequestMatcher.withDefaults();
    private static final PathPatternRequestMatcher API = PATHS.matcher("/api/**");
    private static final PathPatternRequestMatcher SEARCH = PATHS.matcher(HttpMethod.POST, "/api/trip/search");
    private static final PathPatternRequestMatcher RECALCULATE =
            PATHS.matcher(HttpMethod.POST, "/api/trip/search/{searchId}/preferences");
    private static final OrRequestMatcher ROUTE = new OrRequestMatcher(
            PATHS.matcher(HttpMethod.POST, "/api/map/route"),
            PATHS.matcher(HttpMethod.POST, "/api/map/route-with-stops"),
            PATHS.matcher(HttpMethod.POST, "/api/trip"),
            PATHS.matcher(HttpMethod.POST, "/api/template"));
    private static final OrRequestMatcher IMPORT = new OrRequestMatcher(
            PATHS.matcher(HttpMethod.POST, "/api/stop/import/preview"),
            PATHS.matcher(HttpMethod.POST, "/api/stop/import/apply"));

    private final TimeoutProperties properties;

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return !API.matches(request);
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        OperationProfile profile = profile(request);
        var deadline = OperationDeadline.start(profile.budget(properties), profile.sqlLimit(properties));
        try (var ignored = OperationDeadline.install(deadline)) {
            chain.doFilter(request, response);
        }
    }

    private OperationProfile profile(HttpServletRequest request) {
        if (SEARCH.matches(request)) return OperationProfile.SEARCH;
        if (RECALCULATE.matches(request)) return OperationProfile.RECALCULATE;
        if (ROUTE.matches(request)) return OperationProfile.ROUTE;
        if (IMPORT.matches(request)) return OperationProfile.STOP_IMPORT;
        return OperationProfile.STANDARD;
    }
}
