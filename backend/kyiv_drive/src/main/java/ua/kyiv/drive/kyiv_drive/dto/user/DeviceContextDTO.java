package ua.kyiv.drive.kyiv_drive.dto.user;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import ua.kyiv.drive.kyiv_drive.entity.DevicePlatform;

import java.util.UUID;

@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
public class DeviceContextDTO {

    @NotNull(message = "Installation id is required")
    private UUID installationId;

    @NotBlank(message = "Device name is required")
    @Size(max = 120, message = "Device name cannot exceed 120 characters")
    private String deviceName;

    @NotNull(message = "Platform is required")
    private DevicePlatform platform;

    @NotBlank(message = "App version is required")
    @Size(max = 32, message = "App version cannot exceed 32 characters")
    private String appVersion;

    public void setDeviceName(String deviceName) {
        this.deviceName = deviceName != null ? deviceName.strip() : null;
    }

    public void setAppVersion(String appVersion) {
        this.appVersion = appVersion != null ? appVersion.strip() : null;
    }
}
