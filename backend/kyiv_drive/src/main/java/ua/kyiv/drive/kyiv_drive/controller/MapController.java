package ua.kyiv.drive.kyiv_drive.controller;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import ua.kyiv.drive.kyiv_drive.auth.UserPrincipal;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.context.request.async.DeferredResult;
import ua.kyiv.drive.kyiv_drive.dto.map.AddressDTO;
import ua.kyiv.drive.kyiv_drive.dto.map.RouteDTO;
import ua.kyiv.drive.kyiv_drive.dto.map.RouteRequestDTO;
import ua.kyiv.drive.kyiv_drive.dto.map.RouteWithStopsDTO;
import ua.kyiv.drive.kyiv_drive.service.MapService;
import ua.kyiv.drive.kyiv_drive.service.execution.OperationExecutor;
import ua.kyiv.drive.kyiv_drive.service.execution.OperationPlan;
import ua.kyiv.drive.kyiv_drive.service.execution.OperationProfile;
import ua.kyiv.drive.kyiv_drive.validation.InputValidation;
import ua.kyiv.drive.kyiv_drive.validation.ServiceArea;

import java.util.List;

@RestController
@RequestMapping("/api/map")
@RequiredArgsConstructor
@Validated
public class MapController {

    private final MapService mapService;
    private final OperationExecutor executor;

    @GetMapping("/reverse-geocode")
    public ResponseEntity<AddressDTO> reverseGeocode(
            @RequestParam("lat")
            @DecimalMin(value = ServiceArea.MIN_LATITUDE_TEXT, message = "Latitude out of bounds")
            @DecimalMax(value = ServiceArea.MAX_LATITUDE_TEXT, message = "Latitude out of bounds")
            Double lat,

            @RequestParam("lon")
            @DecimalMin(value = ServiceArea.MIN_LONGITUDE_TEXT, message = "Longitude out of bounds")
            @DecimalMax(value = ServiceArea.MAX_LONGITUDE_TEXT, message = "Longitude out of bounds")
            Double lon
    ) {
        return ResponseEntity.ok(mapService.getAddressByCoordinates(lat, lon));
    }

    @GetMapping("/autocomplete")
    public ResponseEntity<List<AddressDTO>> autocompleteAddress(
            @RequestParam("text")
            @NotBlank(message = "Search text cannot be empty")
            @Size(max = 100, message = "Search text cannot exceed 100 characters")
            @Pattern(regexp = InputValidation.ADDRESS_SEARCH_TEXT, message = "Search text contains invalid characters")
            @Pattern(regexp = InputValidation.ADDRESS_SEARCH_MINIMUM, message = "Search text must contain at least 4 letters or digits")
            String text
    ) {
        return ResponseEntity.ok(mapService.autocompleteAddress(text));
    }

    @PostMapping("/route")
    public DeferredResult<RouteDTO> getRoute(
            @Valid @RequestBody RouteRequestDTO request,
            @AuthenticationPrincipal UserPrincipal principal
    ) {
        return executor.execute(new OperationPlan<>(OperationProfile.ROUTE,
                () -> mapService.getRoute(request, principal.getId())));
    }

    @PostMapping("/route-with-stops")
    public DeferredResult<RouteWithStopsDTO> getRouteWithStops(
            @Valid @RequestBody RouteRequestDTO request,
            @AuthenticationPrincipal UserPrincipal principal
    ) {
        return executor.execute(new OperationPlan<>(OperationProfile.ROUTE,
                () -> mapService.getRouteWithStops(request, principal.getId())));
    }
}
