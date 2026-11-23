package ua.kyiv.drive.kyiv_drive.controller;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.context.request.async.DeferredResult;
import ua.kyiv.drive.kyiv_drive.auth.UserPrincipal;
import ua.kyiv.drive.kyiv_drive.dto.search.*;
import ua.kyiv.drive.kyiv_drive.service.search.TripSearchService;
import ua.kyiv.drive.kyiv_drive.service.execution.OperationExecutor;


@RestController
@RequiredArgsConstructor
@RequestMapping("/api/trip/search")
public class TripSearchController {
    private final TripSearchService service;
    private final OperationExecutor executor;

    @PostMapping
    public DeferredResult<TripSearchPageDTO> search(@Valid @RequestBody TripSearchRequestDTO request,
                                     @AuthenticationPrincipal UserPrincipal principal) {
        return executor.execute(service.prepareSearch(request, principal.getId(), principal.getSessionId()));
    }

    @GetMapping("/{searchId}")
    public TripSearchPageDTO page(@PathVariable String searchId, @RequestParam(required = false) String cursor,
                                  @AuthenticationPrincipal UserPrincipal principal) {
        return service.page(searchId, cursor, principal.getId(), principal.getSessionId());
    }

    @PostMapping("/{searchId}/preferences")
    public DeferredResult<TripSearchPageDTO> reprioritize(@PathVariable String searchId,
                                          @Valid @RequestBody TripSearchPreferencesDTO request,
                                          @AuthenticationPrincipal UserPrincipal principal) {
        return executor.execute(service.prepareReprioritization(searchId, request, principal.getId(), principal.getSessionId()));
    }

    @PostMapping("/{searchId}/keep-alive")
    public TripSearchKeepAliveDTO keepAlive(@PathVariable String searchId,
                                            @AuthenticationPrincipal UserPrincipal principal) {
        return service.keepAlive(searchId, principal.getId(), principal.getSessionId());
    }
}
