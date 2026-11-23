package ua.kyiv.drive.kyiv_drive.config;

import io.lettuce.core.ClientOptions;
import io.lettuce.core.SocketOptions;
import io.lettuce.core.resource.ClientResources;
import io.lettuce.core.resource.DefaultClientResources;
import io.lettuce.core.tracing.MicrometerTracing;
import io.micrometer.observation.ObservationRegistry;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.cache.Cache;
import org.springframework.cache.annotation.CachingConfigurer;
import org.springframework.cache.interceptor.CacheErrorHandler;
import org.springframework.cache.interceptor.SimpleCacheErrorHandler;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.cache.RedisCacheConfiguration;
import org.springframework.data.redis.cache.RedisCacheManager;
import org.springframework.data.redis.connection.RedisStandaloneConfiguration;
import org.springframework.data.redis.connection.lettuce.LettuceClientConfiguration;
import org.springframework.data.redis.connection.lettuce.LettuceConnectionFactory;
import org.springframework.data.redis.core.StringRedisTemplate;

import java.time.Duration;
import java.util.Set;

@Slf4j
@Configuration(proxyBeanMethods = false)
@EnableConfigurationProperties(SearchCacheProperties.class)
public class TripSearchCacheConfiguration implements CachingConfigurer {
    @Bean(defaultCandidate = false, destroyMethod = "shutdown")
    public ClientResources searchCacheClientResources(ObjectProvider<ObservationRegistry> observations) {
        var builder = DefaultClientResources.builder();
        var registry = observations.getIfAvailable();
        if (registry != null) builder.tracing(new MicrometerTracing(registry, "Redis cache"));
        return builder.build();
    }

    // Explicit qualifiers keep these beans separate from Boot's persistent Redis defaults.
    @Bean(defaultCandidate = false)
    public LettuceConnectionFactory searchCacheConnectionFactory(SearchCacheProperties properties,
            @Qualifier("searchCacheClientResources") ClientResources resources) {
        var server = new RedisStandaloneConfiguration(properties.getHost(), properties.getPort());
        if (!properties.getUsername().isBlank()) server.setUsername(properties.getUsername());
        if (!properties.getPassword().isBlank()) server.setPassword(properties.getPassword());
        var client = LettuceClientConfiguration.builder()
                .clientOptions(ClientOptions.builder().socketOptions(SocketOptions.builder()
                        .connectTimeout(properties.getCommandTimeout()).build()).build())
                .commandTimeout(properties.getCommandTimeout())
                .shutdownTimeout(Duration.ofMillis(100))
                .clientResources(resources).build();
        return new LettuceConnectionFactory(server, client);
    }

    @Bean(defaultCandidate = false)
    public StringRedisTemplate searchCacheRedisTemplate(
            @Qualifier("searchCacheConnectionFactory") LettuceConnectionFactory factory) {
        return new StringRedisTemplate(factory);
    }

    @Bean
    public RedisCacheManager cacheManager(
            @Qualifier("searchCacheConnectionFactory") LettuceConnectionFactory factory) {
        // Dictionary entries have no TTL. They can be rebuilt from PostgreSQL after eviction.
        return RedisCacheManager.builder(factory)
                .cacheDefaults(RedisCacheConfiguration.defaultCacheConfig(getClass().getClassLoader())
                        .disableCachingNullValues())
                .initialCacheNames(Set.of("car_brands", "car_models"))
                .disableCreateOnMissingCache()
                .build();
    }

    @Override
    public CacheErrorHandler errorHandler() {
        return new SimpleCacheErrorHandler() {
            @Override
            public void handleCacheGetError(RuntimeException exception, Cache cache, Object key) {
                log.warn("Could not read {} cache; loading from PostgreSQL: {}", cache.getName(), exception.getMessage());
            }

            @Override
            public void handleCachePutError(RuntimeException exception, Cache cache, Object key, Object value) {
                log.warn("Could not cache {} data: {}", cache.getName(), exception.getMessage());
            }
        };
    }
}
