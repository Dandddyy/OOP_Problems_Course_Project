package ua.kyiv.drive.kyiv_drive.service;

import lombok.RequiredArgsConstructor;
import org.springframework.context.MessageSource;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import ua.kyiv.drive.kyiv_drive.config.OperationDeadline;
import ua.kyiv.drive.kyiv_drive.dto.map.RouteWithStopsDTO;
import ua.kyiv.drive.kyiv_drive.dto.map.StopOnRouteDTO;
import ua.kyiv.drive.kyiv_drive.dto.template.CreateTemplateWrapperDTO;
import ua.kyiv.drive.kyiv_drive.dto.template.TemplateStopCreateDTO;
import ua.kyiv.drive.kyiv_drive.entity.Stop;
import ua.kyiv.drive.kyiv_drive.entity.Template;
import ua.kyiv.drive.kyiv_drive.entity.TemplateStop;
import ua.kyiv.drive.kyiv_drive.exception.LimitExceededException;
import ua.kyiv.drive.kyiv_drive.exception.ResourceNotFoundException;
import ua.kyiv.drive.kyiv_drive.exception.RouteSnapshotMismatchException;
import ua.kyiv.drive.kyiv_drive.mapper.TemplateMapper;
import ua.kyiv.drive.kyiv_drive.repository.StopRepository;
import ua.kyiv.drive.kyiv_drive.repository.TemplateRepository;
import ua.kyiv.drive.kyiv_drive.repository.UserRepository;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class TemplatePersistenceService {

    private static final int MAX_USER_TEMPLATES = 20;

    private final TemplateRepository templateRepository;
    private final StopRepository stopRepository;
    private final UserRepository userRepository;
    private final TemplateMapper templateMapper;
    private final TemplateRequestMatcher requestMatcher;
    private final MessageSource messageSource;

    public void requireCapacity(UUID userId) {
        if (templateRepository.countByUserId(userId) >= MAX_USER_TEMPLATES) {
            throw new LimitExceededException(getMessage("error.template_limit_exceeded", MAX_USER_TEMPLATES));
        }
    }

    @Transactional
    public TemplateCreationResult create(
            CreateTemplateWrapperDTO request,
            UUID userId,
            RouteWithStopsDTO authoritativeSnapshot,
            long stopsCatalogVersion,
            boolean isDriver
    ) {
        userRepository.findByIdForUpdate(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        Template existing = templateRepository
                .findByUserIdAndRequestIdWithStops(userId, request.getRequestId())
                .orElse(null);
        if (existing != null) {
            requestMatcher.requireSameRequest(existing, request);
            return new TemplateCreationResult(existing.getId(), false);
        }

        requireCapacity(userId);

        Template template = templateMapper.toEntity(request.getTemplate());
        template.setUserId(userId);
        template.setRequestId(request.getRequestId());
        template.setIsDriver(isDriver);
        template.setRoutePolyline(authoritativeSnapshot.getRoute().getPolyline());
        template.setTotalDurationSeconds(authoritativeSnapshot.getRoute().getDurationSeconds());
        template.setTotalDistanceMeters(authoritativeSnapshot.getRoute().getDistanceMeters());
        template.setStopsCatalogVersion(stopsCatalogVersion);

        addStops(template, requestStops(request), snapshotStops(authoritativeSnapshot));

        OperationDeadline.check();
        Template saved = templateRepository.saveAndFlush(template);
        OperationDeadline.check();
        return new TemplateCreationResult(saved.getId(), true);
    }

    private void addStops(
            Template template,
            List<TemplateStopCreateDTO> requestedStops,
            List<StopOnRouteDTO> authoritativeStops
    ) {
        if (requestedStops.size() != authoritativeStops.size()) {
            throw new RouteSnapshotMismatchException();
        }
        if (authoritativeStops.isEmpty()) {
            return;
        }

        for (int index = 0; index < authoritativeStops.size(); index++) {
            if (!Objects.equals(
                    requestedStops.get(index).getStopId(),
                    authoritativeStops.get(index).getStopId()
            )) {
                throw new RouteSnapshotMismatchException();
            }
        }

        List<UUID> stopIds = authoritativeStops.stream().map(StopOnRouteDTO::getStopId).toList();
        Map<UUID, Stop> stopsById = stopRepository.findAllById(stopIds).stream()
                .collect(Collectors.toMap(Stop::getId, Function.identity(), (first, second) -> first, LinkedHashMap::new));

        for (int index = 0; index < authoritativeStops.size(); index++) {
            StopOnRouteDTO snapshotStop = authoritativeStops.get(index);
            TemplateStopCreateDTO requestedStop = requestedStops.get(index);
            Stop stop = stopsById.get(snapshotStop.getStopId());
            if (stop == null || !Boolean.TRUE.equals(stop.getIsActive())) {
                throw new RouteSnapshotMismatchException();
            }

            TemplateStop templateStop = new TemplateStop();
            templateStop.setStop(stop);
            templateStop.setSequenceNumber((short) (index + 1));
            templateStop.setCumulativeDurationSeconds(snapshotStop.getEtaSeconds());
            templateStop.setCumulativeDistanceMeters(snapshotStop.getDistanceMeters());
            templateStop.setIsEnabled(requestedStop.getIsEnabled());
            template.addTemplateStop(templateStop);
        }
    }

    private List<TemplateStopCreateDTO> requestStops(CreateTemplateWrapperDTO request) {
        return request.getStops() == null ? List.of() : request.getStops();
    }

    private List<StopOnRouteDTO> snapshotStops(RouteWithStopsDTO snapshot) {
        return snapshot.getStops() == null ? List.of() : snapshot.getStops();
    }

    private String getMessage(String code, Object... args) {
        return messageSource.getMessage(code, args, LocaleContextHolder.getLocale());
    }
}
