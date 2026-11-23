package ua.kyiv.drive.kyiv_drive.service;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import ua.kyiv.drive.kyiv_drive.dto.map.RouteRequestDTO;
import ua.kyiv.drive.kyiv_drive.dto.map.RouteWithStopsDTO;
import ua.kyiv.drive.kyiv_drive.dto.trip.CreateTripWrapperDTO;
import ua.kyiv.drive.kyiv_drive.dto.trip.TripCreateDTO;
import ua.kyiv.drive.kyiv_drive.dto.trip.TripStopCreateDTO;
import ua.kyiv.drive.kyiv_drive.entity.Trip;
import ua.kyiv.drive.kyiv_drive.exception.RouteSnapshotMismatchException;
import ua.kyiv.drive.kyiv_drive.repository.TripRepository;
import ua.kyiv.drive.kyiv_drive.service.stop.StopImportHistoryService;
import ua.kyiv.drive.kyiv_drive.validation.RouteSnapshotValidator;
import ua.kyiv.drive.kyiv_drive.validation.TripRequestValidator;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class TripService {
    private final TripRepository tripRepository;
    private final TripAuthorizationService authorization;
    private final TripRequestValidator validator;
    private final TripRequestMatcher matcher;
    private final TripPersistenceService persistence;
    private final MapService mapService;
    private final StopImportHistoryService catalog;
    private final Clock clock;

    public TripPublicationResult publish(CreateTripWrapperDTO request, UUID driverId, UUID sessionId) {
        Instant now = clock.instant();
        authorization.requireDriver(driverId, sessionId, now);
        Trip existing = tripRepository.findByDriverIdAndRequestIdWithStops(driverId, request.getRequestId())
                .orElse(null);
        if (existing != null) {
            matcher.requireSameRequest(existing, request);
            return new TripPublicationResult(existing.getId(), false, existing.getConfirmationExpiresAt());
        }
        validator.validate(request, now);
        TripCreateDTO trip = request.getTrip();
        authorization.requireCar(trip.getCarId(), driverId);
        persistence.precheck(request, driverId, now);

        long before = catalog.getCurrentCatalogVersionNumber();
        RouteWithStopsDTO snapshot = mapService.getRouteWithStops(new RouteRequestDTO(
                trip.getStartLat(), trip.getStartLon(), trip.getEndLat(), trip.getEndLon(), trip.getWaypoints()
        ), driverId);
        long after = catalog.getCurrentCatalogVersionNumber();
        List<UUID> stopIds = request.getStops() == null ? List.of()
                : request.getStops().stream().map(TripStopCreateDTO::getStopId).toList();
        if (before != after || !RouteSnapshotValidator.matches(trip.getRoutePolyline(),
                trip.getTotalDistanceMeters(), trip.getTotalDurationSeconds(), stopIds, snapshot)) {
            throw new RouteSnapshotMismatchException();
        }
        return persistence.publish(request, driverId, sessionId, snapshot, after);
    }
}
