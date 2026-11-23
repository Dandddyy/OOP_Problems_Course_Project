package ua.kyiv.drive.kyiv_drive.exception;

import lombok.Getter;

@Getter
public class UserNotRegisteredException extends RuntimeException {
    private final String firstName;

    public UserNotRegisteredException(String firstName) {
        super("User not registered");
        this.firstName = firstName;
    }
}