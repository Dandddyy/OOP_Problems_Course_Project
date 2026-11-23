package ua.kyiv.drive.kyiv_drive.service;

import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import ua.kyiv.drive.kyiv_drive.entity.CurrentMode;
import ua.kyiv.drive.kyiv_drive.exception.SessionNotActiveException;
import ua.kyiv.drive.kyiv_drive.exception.TripPublicationException;
import ua.kyiv.drive.kyiv_drive.repository.CarRepository;
import ua.kyiv.drive.kyiv_drive.repository.UserSessionRepository;

import java.time.Instant;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class TripAuthorizationService {
    private final UserSessionRepository sessionRepository;
    private final CarRepository carRepository;

    public void requireDriver(UUID userId, UUID sessionId, Instant now) {
        if (sessionId == null) {
            throw new SessionNotActiveException();
        }
        CurrentMode mode = sessionRepository.findActiveCurrentMode(sessionId, userId, now)
                .orElseThrow(SessionNotActiveException::new);
        if (mode != CurrentMode.DRIVER) {
            throw new TripPublicationException("trip_driver_required", HttpStatus.FORBIDDEN);
        }
    }

    public void requireCar(UUID carId, UUID driverId) {
        if (carRepository.findByIdAndOwnerIdAndIsDeletedFalse(carId, driverId).isEmpty()) {
            throw carUnavailable();
        }
    }

    public TripPublicationException carUnavailable() {
        return new TripPublicationException("trip_car_unavailable", HttpStatus.BAD_REQUEST);
    }
}
