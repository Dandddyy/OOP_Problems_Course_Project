package ua.kyiv.drive.kyiv_drive.controller;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import ua.kyiv.drive.kyiv_drive.auth.UserPrincipal;
import ua.kyiv.drive.kyiv_drive.dto.car.*;
import ua.kyiv.drive.kyiv_drive.service.CarService;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/car")
@RequiredArgsConstructor
public class CarController {

    private final CarService carService;

    @GetMapping("/init")
    public ResponseEntity<CarInitDataDTO> getInitData(@AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(carService.getInitData(principal.getId()));
    }

    @GetMapping("/models")
    public ResponseEntity<List<CarModelResponseDTO>> getModels(@RequestParam UUID brandId) {
        return ResponseEntity.ok(carService.getModelsByBrand(brandId));
    }

    @PostMapping
    public ResponseEntity<CarResponseDTO> addCar(
            @Valid @RequestBody CarRequestDTO request,
            @AuthenticationPrincipal UserPrincipal principal
            ) {
        return ResponseEntity.ok(carService.addCar(request, principal.getId()));
    }

    @PutMapping("/{id}")
    public ResponseEntity<CarResponseDTO> updateCar(
            @PathVariable UUID id,
            @Valid @RequestBody CarRequestDTO request,
            @AuthenticationPrincipal UserPrincipal principal
    ) {
        return ResponseEntity.ok(carService.updateCar(id, request, principal.getId()));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Map<String, String>> deleteCar(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserPrincipal principal
    ) {
        carService.deleteCar(id, principal.getId());
        return ResponseEntity.ok(Map.of("message", "Car deleted successfully"));
    }
}
