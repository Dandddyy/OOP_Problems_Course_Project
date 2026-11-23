package ua.kyiv.drive.kyiv_drive.controller;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.context.request.async.DeferredResult;
import ua.kyiv.drive.kyiv_drive.auth.UserPrincipal;
import ua.kyiv.drive.kyiv_drive.dto.trip.CreateTripWrapperDTO;
import ua.kyiv.drive.kyiv_drive.dto.trip.TripCreateResponseDTO;
import ua.kyiv.drive.kyiv_drive.service.TripPublicationResult;
import ua.kyiv.drive.kyiv_drive.service.TripService;
import ua.kyiv.drive.kyiv_drive.service.execution.OperationExecutor;
import ua.kyiv.drive.kyiv_drive.service.execution.OperationPlan;
import ua.kyiv.drive.kyiv_drive.service.execution.OperationProfile;

@RestController
@RequestMapping("/api/trip")
@RequiredArgsConstructor
public class TripController {
    private final TripService tripService;
    private final OperationExecutor executor;

    @PostMapping
    public DeferredResult<ResponseEntity<TripCreateResponseDTO>> publish(
            @Valid @RequestBody CreateTripWrapperDTO request,
            @AuthenticationPrincipal UserPrincipal principal
    ) {
        return executor.execute(new OperationPlan<>(OperationProfile.ROUTE, () -> {
            TripPublicationResult result = tripService.publish(request, principal.getId(), principal.getSessionId());
            return ResponseEntity.status(result.created() ? HttpStatus.CREATED : HttpStatus.OK)
                    .body(new TripCreateResponseDTO(result.tripId(), result.created(), result.confirmationExpiresAt(),
                            result.created() ? "Trip published successfully" : "Trip already published"));
        }));
    }
}
