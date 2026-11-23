package ua.kyiv.drive.kyiv_drive.exception;

public class IdempotencyConflictException extends RuntimeException {

    public IdempotencyConflictException() {
        super("The request ID has already been used with different data");
    }
}
