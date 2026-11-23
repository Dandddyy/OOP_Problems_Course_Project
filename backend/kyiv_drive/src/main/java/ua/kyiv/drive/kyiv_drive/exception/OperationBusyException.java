package ua.kyiv.drive.kyiv_drive.exception;

public class OperationBusyException extends RuntimeException {
    public OperationBusyException() {
        super("Operation executor is busy");
    }
}
