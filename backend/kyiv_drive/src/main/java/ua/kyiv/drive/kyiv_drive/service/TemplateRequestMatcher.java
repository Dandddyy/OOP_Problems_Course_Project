package ua.kyiv.drive.kyiv_drive.service;

import org.springframework.stereotype.Component;
import ua.kyiv.drive.kyiv_drive.dto.template.CreateTemplateWrapperDTO;
import ua.kyiv.drive.kyiv_drive.dto.template.TemplateCreateDTO;
import ua.kyiv.drive.kyiv_drive.dto.template.TemplateStopCreateDTO;
import ua.kyiv.drive.kyiv_drive.entity.Template;
import ua.kyiv.drive.kyiv_drive.entity.TemplateStop;
import ua.kyiv.drive.kyiv_drive.entity.TripWaypoint;
import ua.kyiv.drive.kyiv_drive.exception.IdempotencyConflictException;
import ua.kyiv.drive.kyiv_drive.validation.RouteSnapshotValidator;

import java.util.List;
import java.util.Objects;

@Component
public class TemplateRequestMatcher {

    public void requireSameRequest(Template existing, CreateTemplateWrapperDTO request) {
        if (!matches(existing, request)) {
            throw new IdempotencyConflictException();
        }
    }

    private boolean matches(Template existing, CreateTemplateWrapperDTO request) {
        TemplateCreateDTO submitted = request.getTemplate();
        if (submitted == null || existing.getStartLocation() == null || existing.getEndLocation() == null) {
            return false;
        }

        return Objects.equals(existing.getStartShortAddress(), submitted.getStartShortAddress())
                && Objects.equals(existing.getStartSubtitle(), submitted.getStartSubtitle())
                && Objects.equals(existing.getEndShortAddress(), submitted.getEndShortAddress())
                && Objects.equals(existing.getEndSubtitle(), submitted.getEndSubtitle())
                && sameDouble(existing.getStartLocation().getY(), submitted.getStartLat())
                && sameDouble(existing.getStartLocation().getX(), submitted.getStartLon())
                && sameDouble(existing.getEndLocation().getY(), submitted.getEndLat())
                && sameDouble(existing.getEndLocation().getX(), submitted.getEndLon())
                && Objects.equals(normalizeWaypoints(existing.getWaypoints()), normalizeWaypoints(submitted.getWaypoints()))
                && Objects.equals(existing.getRoutePolyline(), submitted.getRoutePolyline())
                && RouteSnapshotValidator.metricsMatch(
                        submitted.getTotalDistanceMeters(),
                        submitted.getTotalDurationSeconds(),
                        existing.getTotalDistanceMeters(),
                        existing.getTotalDurationSeconds()
                )
                && sameStops(existing.getTemplateStops(), normalizeStops(request.getStops()));
    }

    private boolean sameStops(List<TemplateStop> existing, List<TemplateStopCreateDTO> submitted) {
        if (existing.size() != submitted.size()) {
            return false;
        }

        for (int index = 0; index < existing.size(); index++) {
            TemplateStop existingStop = existing.get(index);
            TemplateStopCreateDTO submittedStop = submitted.get(index);
            if (!Objects.equals(existingStop.getStop().getId(), submittedStop.getStopId())
                    || !Objects.equals(existingStop.getIsEnabled(), submittedStop.getIsEnabled())) {
                return false;
            }
        }
        return true;
    }

    private boolean sameDouble(double existing, Double submitted) {
        return submitted != null && Double.compare(existing, submitted) == 0;
    }

    private List<TripWaypoint> normalizeWaypoints(List<TripWaypoint> waypoints) {
        return waypoints == null ? List.of() : waypoints;
    }

    private List<TemplateStopCreateDTO> normalizeStops(List<TemplateStopCreateDTO> stops) {
        return stops == null ? List.of() : stops;
    }
}
