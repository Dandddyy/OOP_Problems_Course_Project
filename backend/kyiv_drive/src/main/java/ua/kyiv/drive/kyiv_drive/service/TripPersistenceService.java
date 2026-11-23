package ua.kyiv.drive.kyiv_drive.service;

import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import ua.kyiv.drive.kyiv_drive.config.OperationDeadline;
import ua.kyiv.drive.kyiv_drive.config.TripProperties;
import ua.kyiv.drive.kyiv_drive.dto.map.RouteWithStopsDTO;
import ua.kyiv.drive.kyiv_drive.dto.map.StopOnRouteDTO;
import ua.kyiv.drive.kyiv_drive.dto.trip.CreateTripWrapperDTO;
import ua.kyiv.drive.kyiv_drive.dto.trip.TripStopCreateDTO;
import ua.kyiv.drive.kyiv_drive.entity.*;
import ua.kyiv.drive.kyiv_drive.exception.RouteSnapshotMismatchException;
import ua.kyiv.drive.kyiv_drive.exception.SessionNotActiveException;
import ua.kyiv.drive.kyiv_drive.exception.TripPublicationException;
import ua.kyiv.drive.kyiv_drive.mapper.TripMapper;
import ua.kyiv.drive.kyiv_drive.repository.*;
import ua.kyiv.drive.kyiv_drive.service.stop.StopImportHistoryService;
import ua.kyiv.drive.kyiv_drive.validation.TripPolicy;
import ua.kyiv.drive.kyiv_drive.validation.TripRequestValidator;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class TripPersistenceService {
    private final TripRepository tripRepository;
    private final UserRepository userRepository;
    private final CarRepository carRepository;
    private final StopRepository stopRepository;
    private final TripAuthorizationService authorization;
    private final TripRequestValidator validator;
    private final TripRequestMatcher matcher;
    private final TripMapper mapper;
    private final StopImportHistoryService catalog;
    private final TripProperties properties;
    private final Clock clock;

    public void precheck(CreateTripWrapperDTO request, UUID driverId, Instant now) {
        requireCapacity(tripRepository.countActiveForPublication(driverId, now));
        requireNoDuplicate(request, driverId);
    }

    @Transactional
    public TripPublicationResult publish(CreateTripWrapperDTO request, UUID driverId, UUID sessionId,
                                         RouteWithStopsDTO snapshot, long catalogVersion) {
        userRepository.findByIdForUpdate(driverId).filter(user -> Boolean.TRUE.equals(user.getIsActive()))
                .orElseThrow(SessionNotActiveException::new);
        Instant now = clock.instant();
        authorization.requireDriver(driverId, sessionId, now);
        Trip existing = tripRepository.findByDriverIdAndRequestIdWithStops(driverId, request.getRequestId())
                .orElse(null);
        if (existing != null) {
            matcher.requireSameRequest(existing, request);
            return new TripPublicationResult(existing.getId(), false, existing.getConfirmationExpiresAt());
        }
        validator.validate(request, now);
        Car car = carRepository.findByIdForUpdate(request.getTrip().getCarId())
                .orElseThrow(authorization::carUnavailable);
        if (car.isDeleted() || !driverId.equals(car.getOwnerId())) {
            throw authorization.carUnavailable();
        }
        tripRepository.expireCompletedOneTimeTrips(driverId, now);
        requireCapacity(tripRepository.countByDriverIdAndTripStatus(driverId, TripStatus.ACTIVE));
        requireNoDuplicate(request, driverId);

        Trip trip = mapper.toEntity(request.getTrip());
        trip.setDriverId(driverId);
        trip.setRequestId(request.getRequestId());
        trip.setRoutePolyline(snapshot.getRoute().getPolyline());
        trip.setTotalDistanceMeters(snapshot.getRoute().getDistanceMeters());
        trip.setTotalDurationSeconds(snapshot.getRoute().getDurationSeconds());
        trip.setTripStatus(TripStatus.ACTIVE);
        trip.setRecruitmentStatus(TripRecruitmentStatus.OPEN);
        trip.setStopsCatalogVersion(catalogVersion);
        if (trip.getScheduleType() == TripScheduleType.RECURRING) {
            trip.setLastConfirmedAt(now);
            trip.setConfirmationExpiresAt(now.plus(TripPolicy.CONFIRMATION_TTL));
        }
        addStops(trip, request.getStops() == null ? List.of() : request.getStops(), snapshot);
        if (catalog.getCurrentCatalogVersionNumber() != catalogVersion) {
            throw new RouteSnapshotMismatchException();
        }
        OperationDeadline.check();
        Trip saved = tripRepository.saveAndFlush(trip);
        OperationDeadline.check();
        return new TripPublicationResult(saved.getId(), true, saved.getConfirmationExpiresAt());
    }

    private void requireCapacity(long count) {
        if (count >= properties.getMaxActiveTrips()) {
            throw new TripPublicationException("trip_active_limit_reached", HttpStatus.BAD_REQUEST,
                    properties.getMaxActiveTrips());
        }
    }

    private void requireNoDuplicate(CreateTripWrapperDTO request, UUID driverId) {
        if (tripRepository.findAllByDriverIdAndTripStatus(driverId, TripStatus.ACTIVE).stream()
                .anyMatch(trip -> matcher.isDuplicate(trip, request.getTrip()))) {
            throw new TripPublicationException("trip_duplicate", HttpStatus.CONFLICT);
        }
    }

    private void addStops(Trip trip, List<TripStopCreateDTO> requestedStops, RouteWithStopsDTO snapshot) {
        List<StopOnRouteDTO> calculatedStops = snapshot.getStops() == null ? List.of() : snapshot.getStops();
        if (requestedStops.size() != calculatedStops.size()) {
            throw new RouteSnapshotMismatchException();
        }
        if (calculatedStops.isEmpty()) {
            return;
        }
        List<UUID> ids = calculatedStops.stream().map(StopOnRouteDTO::getStopId).toList();
        Map<UUID, Stop> catalogStops = stopRepository.findAllByIdForShare(ids).stream()
                .collect(Collectors.toMap(Stop::getId, Function.identity()));
        for (int index = 0; index < calculatedStops.size(); index++) {
            StopOnRouteDTO calculated = calculatedStops.get(index);
            TripStopCreateDTO requested = requestedStops.get(index);
            Stop stop = catalogStops.get(calculated.getStopId());
            if (!Objects.equals(calculated.getStopId(), requested.getStopId())
                    || stop == null || !Boolean.TRUE.equals(stop.getIsActive())) {
                throw new RouteSnapshotMismatchException();
            }
            TripStop tripStop = new TripStop();
            tripStop.setStop(stop);
            tripStop.setSequenceNumber((short) (index + 1));
            tripStop.setIsEnabled(requested.getIsEnabled());
            tripStop.setCumulativeDistanceMeters(calculated.getDistanceMeters());
            tripStop.setCumulativeDurationSeconds(calculated.getEtaSeconds());
            tripStop.setStopNameSnapshot(calculated.getName());
            tripStop.setStopLocationSnapshot(mapper.toPoint(calculated.getLon(), calculated.getLat()));
            trip.addTripStop(tripStop);
        }
    }
}
