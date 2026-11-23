package ua.kyiv.drive.kyiv_drive.config;

import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Getter
@Setter
@Component
@ConfigurationProperties(prefix = "app.client-version")
public class ClientVersionProperties {

    private String minimumAndroid;
    private String minimumIos;
}
