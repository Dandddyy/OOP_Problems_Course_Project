package ua.kyiv.drive.kyiv_drive.controller;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/config")
public class AppConfigController {

    @Value("${map.url-template}")
    private String urlTemplate;

    @Value("${map.access-token}")
    private String accessToken;

    public record MapConfigResponse(String urlTemplate, String accessToken) {}

    @GetMapping("/map")
    public MapConfigResponse getMapConfig() {
        return new MapConfigResponse(urlTemplate, accessToken);
    }
}