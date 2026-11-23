package ua.kyiv.drive.kyiv_drive.exception;

public class SessionNotActiveException extends RuntimeException {

    public SessionNotActiveException() {
        super("Session is not active");
    }
}
