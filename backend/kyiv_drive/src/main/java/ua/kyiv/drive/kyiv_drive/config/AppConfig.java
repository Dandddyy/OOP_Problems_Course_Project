package ua.kyiv.drive.kyiv_drive.config;

import io.micrometer.observation.ObservationRegistry;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestTemplate;

@Configuration
public class AppConfig {
    @Bean
    public DependencyRequestFactory dependencyRequestFactory(TimeoutProperties properties) {
        return new DependencyRequestFactory(properties);
    }

    @Bean
    public RestTemplate restTemplate(ObservationRegistry registry, DependencyRequestFactory factory) {
        return DependencyHttpMetrics.observe(new RestTemplate(factory), registry, DependencyRequestFactory::dependency);
    }
}
