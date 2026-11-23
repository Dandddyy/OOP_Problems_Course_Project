package ua.kyiv.drive.kyiv_drive.config;

import io.micrometer.observation.ObservationRegistry;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestTemplate;

@Configuration(proxyBeanMethods = false)
@EnableConfigurationProperties(WalkingRoutingProperties.class)
public class WalkingRoutingConfiguration {
    @Bean
    public WalkingOsrmRequestFactory walkingOsrmRequestFactory(WalkingRoutingProperties properties) {
        return new WalkingOsrmRequestFactory(properties);
    }

    @Bean(defaultCandidate = false)
    public RestTemplate walkingOsrmRestTemplate(WalkingOsrmRequestFactory factory, ObservationRegistry observations) {
        return DependencyHttpMetrics.observe(new RestTemplate(factory), observations, uri -> "osrm_foot");
    }
}
