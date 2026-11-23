package ua.kyiv.drive.kyiv_drive.exception;

import io.micrometer.core.instrument.MeterRegistry;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.ConstraintViolationException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.MessageSource;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.method.annotation.HandlerMethodValidationException;

import javax.security.auth.login.AccountLockedException;
import javax.security.auth.login.CredentialException;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;

@Slf4j
@RestControllerAdvice
@RequiredArgsConstructor
public class GlobalExceptionHandler {

    private final MessageSource messageSource;
    private final MeterRegistry meters;

    @ExceptionHandler(TripSearchException.class)
    public ResponseEntity<?> handleTripSearch(TripSearchException e) {
        if (e.getStatus() == HttpStatus.TOO_MANY_REQUESTS || e.getStatus() == HttpStatus.SERVICE_UNAVAILABLE) {
            recordRefusal(e.getCode(), e.getStatus());
        }
        boolean showUser = e.getStatus() != HttpStatus.BAD_REQUEST
                || "trip_departure_in_past".equals(e.getCode());
        String message = messageSource.getMessage("error." + e.getCode(), null,
                e.getCode(), LocaleContextHolder.getLocale());
        return ResponseEntity.status(e.getStatus()).body(Map.of(
                "code", e.getCode(), "message", message, "showUser", showUser
        ));
    }

    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    public ResponseEntity<?> handleInvalidParameter(MethodArgumentTypeMismatchException e) {
        return ResponseEntity.badRequest().body(Map.of("message", "Invalid request parameter", "showUser", false));
    }

    @ExceptionHandler(TripPublicationException.class)
    public ResponseEntity<?> handleTripPublication(TripPublicationException e) {
        String message = e.isUserFacing()
                ? messageSource.getMessage("error." + e.getCode(), e.getArguments(),
                        e.getMessage(), LocaleContextHolder.getLocale())
                : e.getMessage();
        return ResponseEntity.status(e.getStatus()).body(Map.of(
                "code", e.getCode(), "message", message, "showUser", e.isUserFacing()
        ));
    }

    @ExceptionHandler(FieldValidationException.class)
    public ResponseEntity<?> handleFieldValidation(FieldValidationException e) {
        return ResponseEntity.badRequest().body(Map.of(
                "type", "field_error",
                "field", e.getField(),
                "message", e.getMessage(),
                "showUser", true
        ));
    }

    @ExceptionHandler(CredentialException.class)
    public ResponseEntity<?> handleCredentials(CredentialException e, HttpServletRequest request) {
        boolean isRefreshEndpoint = request.getRequestURI().endsWith("/refresh");

        return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of(
                "message", e.getMessage(),
                "showUser", !isRefreshEndpoint
        ));
    }

    @ExceptionHandler(InvalidRefreshTokenException.class)
    public ResponseEntity<?> handleInvalidRefreshToken(InvalidRefreshTokenException e) {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of(
                "code", "invalid_refresh_token",
                "message", e.getMessage(),
                "showUser", false
        ));
    }

    @ExceptionHandler(SessionNotActiveException.class)
    public ResponseEntity<?> handleSessionNotActive(SessionNotActiveException e) {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of(
                "code", "session_not_active",
                "message", e.getMessage(),
                "showUser", false
        ));
    }

    @ExceptionHandler(AppUpdateRequiredException.class)
    public ResponseEntity<?> handleAppUpdateRequired(AppUpdateRequiredException e) {
        String message = messageSource.getMessage(
                "error.app_update_required",
                null,
                "This version of the app is no longer supported. Please update it to continue.",
                LocaleContextHolder.getLocale()
        );
        return ResponseEntity.status(HttpStatus.UPGRADE_REQUIRED).body(Map.of(
                "code", "app_update_required",
                "message", message,
                "showUser", true,
                "platform", e.getPlatform().name(),
                "minimumVersion", e.getMinimumVersion()
        ));
    }

    @ExceptionHandler(AccountLockedException.class)
    public ResponseEntity<?> handleAccountLocked(AccountLockedException e, HttpServletRequest request) {
        boolean isRefreshEndpoint = request.getRequestURI().endsWith("/refresh");

        return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of(
                "message", e.getMessage(),
                "showUser", !isRefreshEndpoint
        ));
    }

    @ExceptionHandler(UserNotRegisteredException.class)
    public ResponseEntity<?> handleUserNotRegistered(UserNotRegisteredException e) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of(
                "message", "User not registered",
                "needRegistration", true,
                "firstName", e.getFirstName()
        ));
    }

    @ExceptionHandler(RateLimitException.class)
    public ResponseEntity<?> handleRateLimit(RateLimitException e) {
        recordRefusal(e.getCode(), e.getStatus());
        String key = "error." + e.getCode();
        String fallback = messageSource.getMessage(key, null, e.getCode(), Locale.ENGLISH);
        String message = messageSource.getMessage(key, null, fallback, LocaleContextHolder.getLocale());
        return ResponseEntity.status(e.getStatus()).body(Map.of(
                "code", e.getCode(), "message", message, "showUser", true));
    }

    private void recordRefusal(String code, HttpStatus status) {
        meters.counter("kyivdrive.request.refusals", "code", code, "status", Integer.toString(status.value())).increment();
    }

    @ExceptionHandler(OtpException.class)
    public ResponseEntity<?> handleOtpException(OtpException e) {
        return ResponseEntity.badRequest().body(Map.of(
                "message", e.getMessage(),
                "showUser", true
        ));
    }

    @ExceptionHandler(ResourceNotFoundException.class)
    public ResponseEntity<?> handleResourceNotFound(ResourceNotFoundException e) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("message", e.getMessage()));
    }

    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<?> handleAccessDenied(AccessDeniedException e) {
        return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of("message", e.getMessage()));
    }

    @ExceptionHandler(RouteSnapshotMismatchException.class)
    public ResponseEntity<?> handleRouteSnapshotMismatch(RouteSnapshotMismatchException e) {
        String message = messageSource.getMessage(
                "error.route_snapshot_changed",
                null,
                "The route has changed. Refresh it and try again.",
                LocaleContextHolder.getLocale()
        );
        return ResponseEntity.status(HttpStatus.CONFLICT).body(Map.of(
                "code", "route_snapshot_changed",
                "message", message,
                "showUser", true,
                "refreshRoute", true
        ));
    }

    @ExceptionHandler(IdempotencyConflictException.class)
    public ResponseEntity<?> handleIdempotencyConflict(IdempotencyConflictException e) {
        return ResponseEntity.status(HttpStatus.CONFLICT).body(Map.of(
                "code", "request_id_conflict",
                "message", e.getMessage(),
                "showUser", false
        ));
    }

    @ExceptionHandler(RouteSamePointsException.class)
    public ResponseEntity<?> handleRouteSamePoints(RouteSamePointsException e) {
        String message = messageSource.getMessage("error.route_same_points", null,
                "Start and destination must be different locations.", LocaleContextHolder.getLocale());
        return ResponseEntity.badRequest().body(Map.of(
                "code", "route_same_points", "message", message, "showUser", true));
    }

    @ExceptionHandler(RouteTooShortException.class)
    public ResponseEntity<?> handleRouteTooShort(RouteTooShortException e) {
        String message = messageSource.getMessage(
                "error.route_too_short",
                new Object[]{e.getMinimumDistanceMeters() / 1000.0},
                "The route is too short. Select points farther apart.",
                LocaleContextHolder.getLocale()
        );
        return ResponseEntity.badRequest().body(Map.of(
                "code", "route_too_short",
                "minimumDistanceMeters", e.getMinimumDistanceMeters(),
                "message", message,
                "showUser", true
        ));
    }

    @ExceptionHandler(RouteTooLongException.class)
    public ResponseEntity<?> handleRouteTooLong(RouteTooLongException e) {
        String message = messageSource.getMessage(
                "error.route_too_long",
                new Object[]{e.getMaximumDistanceMeters() / 1000},
                "The route is too long. Select closer points or change the waypoints.",
                LocaleContextHolder.getLocale()
        );
        return ResponseEntity.badRequest().body(Map.of(
                "code", "route_too_long",
                "maximumDistanceMeters", e.getMaximumDistanceMeters(),
                "message", message,
                "showUser", true
        ));
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<?> handleIllegalArgument(IllegalArgumentException e) {
        return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<?> handleUnreadableRequestBody(HttpMessageNotReadableException e) {
        return ResponseEntity.badRequest().body(Map.of(
                "message", "Invalid request body",
                "showUser", false
        ));
    }

    @ExceptionHandler(RuntimeException.class)
    public ResponseEntity<?> handleAllOtherExceptions(RuntimeException e) {
        if (OperationTimeoutException.causedByTimeout(e)) return handleOperationTimeout();
        log.error("System Error: {}", e.getMessage(), e);
        e.printStackTrace();
        return ResponseEntity.internalServerError().body(Map.of(
                "message", "Internal server error. Please try again later."
        ));
    }

    @ExceptionHandler(OperationTimeoutException.class)
    public ResponseEntity<?> handleOperationTimeout() {
        recordRefusal("operation_timeout", HttpStatus.SERVICE_UNAVAILABLE);
        String message = messageSource.getMessage("error.operation_timeout", null,
                "The request took too long. Please try again later.", LocaleContextHolder.getLocale());
        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
                .body(Map.of("code", "operation_timeout", "message", message, "showUser", true));
    }

    @ExceptionHandler(OperationBusyException.class)
    public ResponseEntity<?> handleOperationBusy() {
        recordRefusal("operation_busy", HttpStatus.SERVICE_UNAVAILABLE);
        String message = messageSource.getMessage("error.operation_busy", null,
                "The service is busy. Please try again later.", LocaleContextHolder.getLocale());
        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
                .body(Map.of("code", "operation_busy", "message", message, "showUser", true));
    }

    @ExceptionHandler(LimitExceededException.class)
    public ResponseEntity<?> handleLimitExceeded(LimitExceededException e) {
        return ResponseEntity.badRequest().body(Map.of(
                "message", e.getMessage(),
                "showUser", true
        ));
    }

    @ExceptionHandler(IllegalStateException.class)
    public ResponseEntity<?> handleIllegalState(IllegalStateException e) {
        return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
    }

    @ExceptionHandler(FileValidationException.class)
    public ResponseEntity<?> handleFileValidation(FileValidationException e) {
        return ResponseEntity.badRequest().body(Map.of(
                "message", e.getMessage(),
                "showUser", true
        ));
    }

    @ExceptionHandler(FileProcessingException.class)
    public ResponseEntity<?> handleFileProcessing(FileProcessingException e) {
        return ResponseEntity.internalServerError().body(Map.of(
                "message", e.getMessage(),
                "showUser", true
        ));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<?> handleValidationExceptions(MethodArgumentNotValidException e) {
        var firstError = e.getBindingResult().getFieldErrors().getFirst();

        String field = firstError.getField();
        String rawMessage = firstError.getDefaultMessage() != null ? firstError.getDefaultMessage() : "Invalid value";

        return ResponseEntity.badRequest().body(Map.of(
                "type", "field_error",
                "field", field,
                "message", rawMessage,
                "showUser", false
        ));
    }

    @ExceptionHandler(HandlerMethodValidationException.class)
    public ResponseEntity<?> handleMethodValidation(HandlerMethodValidationException e) {
        String field = e.getParameterValidationResults().stream()
                .map(result -> result.getMethodParameter().getParameterName())
                .filter(Objects::nonNull).findFirst().orElse("request");
        var firstError = e.getAllErrors().getFirst();
        String message = firstError.getDefaultMessage() != null ? firstError.getDefaultMessage() : "Invalid value";
        return ResponseEntity.status(e.getStatusCode()).body(Map.of(
                "type", "field_error",
                "field", field,
                "message", message,
                "showUser", false
        ));
    }

    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<?> handleConstraintViolation(ConstraintViolationException e) {
        var violation = e.getConstraintViolations().iterator().next();

        String field = violation.getPropertyPath().toString();
        if (field.contains(".")) {
            field = field.substring(field.lastIndexOf('.') + 1);
        }

        return ResponseEntity.badRequest().body(Map.of(
                "type", "field_error",
                "field", field,
                "message", violation.getMessage() != null ? violation.getMessage() : "Invalid value",
                "showUser", false
        ));
    }
}
