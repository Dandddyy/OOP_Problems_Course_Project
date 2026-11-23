package ua.kyiv.drive.kyiv_drive.service;

import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import ua.kyiv.drive.kyiv_drive.config.ClientVersionProperties;
import ua.kyiv.drive.kyiv_drive.dto.user.DeviceContextDTO;
import ua.kyiv.drive.kyiv_drive.entity.DevicePlatform;
import ua.kyiv.drive.kyiv_drive.exception.AppUpdateRequiredException;

import java.math.BigInteger;
import java.util.EnumMap;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Service
public class ClientVersionPolicy {

    private static final Pattern VERSION_PATTERN = Pattern.compile(
            "^(\\d+)\\.(\\d+)\\.(\\d+)(?:\\+(\\d+))?$"
    );

    private final Map<DevicePlatform, MinimumVersion> minimumVersions = new EnumMap<>(DevicePlatform.class);

    public ClientVersionPolicy(ClientVersionProperties properties) {
        addConfiguredMinimum(DevicePlatform.ANDROID, properties.getMinimumAndroid());
        addConfiguredMinimum(DevicePlatform.IOS, properties.getMinimumIos());
    }

    public void requireSupported(DeviceContextDTO device) {
        MinimumVersion minimum = minimumVersions.get(device.getPlatform());
        if (minimum == null) {
            return;
        }

        ParsedVersion installed = parse(device.getAppVersion());
        if (installed == null || installed.compareTo(minimum.parsed()) < 0) {
            throw new AppUpdateRequiredException(device.getPlatform(), minimum.configuredValue());
        }
    }

    private void addConfiguredMinimum(DevicePlatform platform, String configuredValue) {
        if (!StringUtils.hasText(configuredValue)) {
            return;
        }

        String normalized = configuredValue.strip();
        ParsedVersion parsed = parse(normalized);
        if (parsed == null) {
            throw new IllegalStateException(
                    "Minimum " + platform + " app version must use major.minor.patch or major.minor.patch+build"
            );
        }
        minimumVersions.put(platform, new MinimumVersion(normalized, parsed));
    }

    private ParsedVersion parse(String value) {
        if (!StringUtils.hasText(value)) {
            return null;
        }

        Matcher matcher = VERSION_PATTERN.matcher(value.strip());
        if (!matcher.matches()) {
            return null;
        }

        return new ParsedVersion(
                new BigInteger(matcher.group(1)),
                new BigInteger(matcher.group(2)),
                new BigInteger(matcher.group(3)),
                matcher.group(4) == null ? BigInteger.ZERO : new BigInteger(matcher.group(4))
        );
    }

    private record MinimumVersion(String configuredValue, ParsedVersion parsed) {
    }

    private record ParsedVersion(
            BigInteger major,
            BigInteger minor,
            BigInteger patch,
            BigInteger build
    ) implements Comparable<ParsedVersion> {

        @Override
        public int compareTo(ParsedVersion other) {
            int result = major.compareTo(other.major);
            if (result != 0) {
                return result;
            }
            result = minor.compareTo(other.minor);
            if (result != 0) {
                return result;
            }
            result = patch.compareTo(other.patch);
            if (result != 0) {
                return result;
            }
            return build.compareTo(other.build);
        }
    }
}
