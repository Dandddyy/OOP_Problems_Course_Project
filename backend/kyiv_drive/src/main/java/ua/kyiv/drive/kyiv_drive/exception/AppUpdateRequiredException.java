package ua.kyiv.drive.kyiv_drive.exception;

import lombok.Getter;
import ua.kyiv.drive.kyiv_drive.entity.DevicePlatform;

@Getter
public class AppUpdateRequiredException extends RuntimeException {

    private final DevicePlatform platform;
    private final String minimumVersion;

    public AppUpdateRequiredException(DevicePlatform platform, String minimumVersion) {
        super("The installed application version is no longer supported");
        this.platform = platform;
        this.minimumVersion = minimumVersion;
    }
}
