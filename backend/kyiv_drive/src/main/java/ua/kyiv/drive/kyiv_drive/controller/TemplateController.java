package ua.kyiv.drive.kyiv_drive.controller;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.context.request.async.DeferredResult;
import ua.kyiv.drive.kyiv_drive.auth.UserPrincipal;
import ua.kyiv.drive.kyiv_drive.dto.template.CreateTemplateWrapperDTO;
import ua.kyiv.drive.kyiv_drive.dto.template.TemplateCreateResponseDTO;
import ua.kyiv.drive.kyiv_drive.dto.template.TemplateResponseWrapperDTO;
import ua.kyiv.drive.kyiv_drive.service.TemplateCreationResult;
import ua.kyiv.drive.kyiv_drive.service.TemplateService;
import ua.kyiv.drive.kyiv_drive.service.execution.OperationExecutor;
import ua.kyiv.drive.kyiv_drive.service.execution.OperationPlan;
import ua.kyiv.drive.kyiv_drive.service.execution.OperationProfile;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/template")
@RequiredArgsConstructor
public class TemplateController {

    private final TemplateService templateService;
    private final OperationExecutor executor;

    @PostMapping
    public DeferredResult<ResponseEntity<TemplateCreateResponseDTO>> createTemplate(
            @Valid @RequestBody CreateTemplateWrapperDTO request,
            @AuthenticationPrincipal UserPrincipal principal
    ) {
        return executor.execute(new OperationPlan<>(OperationProfile.ROUTE, () -> {
            TemplateCreationResult result = templateService.createTemplate(
                    request, principal.getId(), principal.getSessionId());
            HttpStatus status = result.created() ? HttpStatus.CREATED : HttpStatus.OK;
            String message = result.created() ? "Template created successfully" : "Template already created";
            return ResponseEntity.status(status).body(new TemplateCreateResponseDTO(
                    result.templateId(), result.created(), message));
        }));
    }

    @GetMapping
    public ResponseEntity<List<TemplateResponseWrapperDTO>> getTemplates(
            @RequestParam("is_driver") Boolean isDriver,
            @AuthenticationPrincipal UserPrincipal principal
    ) {
        return ResponseEntity.ok(templateService.getUserTemplates(isDriver, principal.getId()));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Map<String, String>> deleteTemplate(
            @PathVariable("id") UUID id,
            @AuthenticationPrincipal UserPrincipal principal
    ) {
        templateService.deleteTemplate(id, principal.getId());
        return ResponseEntity.ok(Map.of("message", "Template deleted successfully"));
    }
}
