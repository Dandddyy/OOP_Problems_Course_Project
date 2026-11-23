package ua.kyiv.drive.kyiv_drive.service;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import ua.kyiv.drive.kyiv_drive.dto.map.RouteDTO;
import ua.kyiv.drive.kyiv_drive.dto.map.RouteRequestDTO;
import ua.kyiv.drive.kyiv_drive.dto.map.RouteWithStopsDTO;
import ua.kyiv.drive.kyiv_drive.dto.template.CreateTemplateWrapperDTO;
import ua.kyiv.drive.kyiv_drive.dto.template.TemplateCreateDTO;
import ua.kyiv.drive.kyiv_drive.dto.template.TemplateResponseWrapperDTO;
import ua.kyiv.drive.kyiv_drive.dto.template.TemplateStopCreateDTO;
import ua.kyiv.drive.kyiv_drive.entity.CurrentMode;
import ua.kyiv.drive.kyiv_drive.entity.Template;
import ua.kyiv.drive.kyiv_drive.exception.AccessDeniedException;
import ua.kyiv.drive.kyiv_drive.exception.ResourceNotFoundException;
import ua.kyiv.drive.kyiv_drive.exception.RouteSnapshotMismatchException;
import ua.kyiv.drive.kyiv_drive.exception.SessionNotActiveException;
import ua.kyiv.drive.kyiv_drive.mapper.TemplateMapper;
import ua.kyiv.drive.kyiv_drive.mapper.TemplateStopMapper;
import ua.kyiv.drive.kyiv_drive.repository.TemplateRepository;
import ua.kyiv.drive.kyiv_drive.repository.UserSessionRepository;
import ua.kyiv.drive.kyiv_drive.service.stop.StopImportHistoryService;
import ua.kyiv.drive.kyiv_drive.validation.RoutePolicyValidator;
import ua.kyiv.drive.kyiv_drive.validation.RouteSnapshotValidator;

import java.time.Clock;
import java.util.HashSet;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class TemplateService {

    private final TemplateRepository templateRepository;
    private final TemplateMapper templateMapper;
    private final TemplateStopMapper templateStopMapper;
    private final MapService mapService;
    private final StopImportHistoryService stopImportHistoryService;
    private final TemplatePersistenceService persistenceService;
    private final TemplateRequestMatcher requestMatcher;
    private final UserSessionRepository userSessionRepository;
    private final Clock clock;

    public TemplateCreationResult createTemplate(
            CreateTemplateWrapperDTO request,
            UUID userId,
            UUID sessionId
    ) {
        Template existing = templateRepository
                .findByUserIdAndRequestIdWithStops(userId, request.getRequestId())
                .orElse(null);
        if (existing != null) {
            requestMatcher.requireSameRequest(existing, request);
            return new TemplateCreationResult(existing.getId(), false);
        }

        TemplateCreateDTO templateRequest = request.getTemplate();
        RoutePolicyValidator.validateInput(
                templateRequest.getStartLat(),
                templateRequest.getStartLon(),
                templateRequest.getEndLat(),
                templateRequest.getEndLon(),
                templateRequest.getWaypoints()
        );

        boolean isDriver = resolveIsDriver(userId, sessionId);
        List<TemplateStopCreateDTO> requestedStops = request.getStops() == null ? List.of() : request.getStops();
        validateRequestedStops(isDriver, requestedStops);
        persistenceService.requireCapacity(userId);

        RouteRequestDTO routeRequest = new RouteRequestDTO(
                templateRequest.getStartLat(),
                templateRequest.getStartLon(),
                templateRequest.getEndLat(),
                templateRequest.getEndLon(),
                templateRequest.getWaypoints()
        );

        long catalogVersionBefore = isDriver
                ? stopImportHistoryService.getCurrentCatalogVersionNumber()
                : 0L;
        RouteWithStopsDTO authoritativeSnapshot = calculateSnapshot(routeRequest, isDriver, userId);
        long catalogVersionAfter = isDriver
                ? stopImportHistoryService.getCurrentCatalogVersionNumber()
                : 0L;

        if (isDriver && catalogVersionBefore != catalogVersionAfter) {
            throw new RouteSnapshotMismatchException();
        }

        List<UUID> requestedStopIds = requestedStops.stream()
                .map(TemplateStopCreateDTO::getStopId)
                .toList();
        if (!RouteSnapshotValidator.matches(
                templateRequest.getRoutePolyline(),
                templateRequest.getTotalDistanceMeters(),
                templateRequest.getTotalDurationSeconds(),
                requestedStopIds,
                authoritativeSnapshot
        )) {
            throw new RouteSnapshotMismatchException();
        }

        return persistenceService.create(
                request,
                userId,
                authoritativeSnapshot,
                catalogVersionAfter,
                isDriver
        );

    }

    @Transactional(readOnly = true)
    public List<TemplateResponseWrapperDTO> getUserTemplates(Boolean isDriver, UUID userId) {
        if (isDriver == null) {
            throw new IllegalArgumentException("is_driver parameter is required");
        }

        return templateRepository.findAllByUserIdAndIsDriverWithStops(userId, isDriver).stream()
                .map(template -> new TemplateResponseWrapperDTO(
                        templateMapper.toDTO(template),
                        templateStopMapper.toDTOList(template.getTemplateStops())
                ))
                .toList();
    }

    @Transactional
    public void deleteTemplate(UUID templateId, UUID userId) {
        Template template = templateRepository.findById(templateId)
                .orElseThrow(() -> new ResourceNotFoundException("Template not found"));

        if (!template.getUserId().equals(userId)) {
            throw new AccessDeniedException("You don't have permission to delete this template");
        }

        templateRepository.delete(template);
    }

    private RouteWithStopsDTO calculateSnapshot(RouteRequestDTO request, boolean isDriver, UUID userId) {
        if (isDriver) {
            return mapService.getRouteWithStops(request, userId);
        }

        RouteDTO route = mapService.getRoute(request, userId);
        return new RouteWithStopsDTO(route, List.of());
    }

    private boolean resolveIsDriver(UUID userId, UUID sessionId) {
        if (sessionId == null) {
            throw new SessionNotActiveException();
        }

        CurrentMode currentMode = userSessionRepository
                .findActiveCurrentMode(sessionId, userId, clock.instant())
                .orElseThrow(SessionNotActiveException::new);
        return currentMode == CurrentMode.DRIVER;
    }

    private void validateRequestedStops(boolean isDriver, List<TemplateStopCreateDTO> stops) {
        if (!isDriver && !stops.isEmpty()) {
            throw new IllegalArgumentException("Passenger templates cannot contain driver stops");
        }

        HashSet<UUID> uniqueStopIds = new HashSet<>();
        for (TemplateStopCreateDTO stop : stops) {
            if (!uniqueStopIds.add(stop.getStopId())) {
                throw new IllegalArgumentException("Route stops cannot contain duplicate IDs");
            }
        }
    }
}
