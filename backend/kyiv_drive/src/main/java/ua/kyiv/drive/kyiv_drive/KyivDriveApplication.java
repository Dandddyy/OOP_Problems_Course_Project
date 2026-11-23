package ua.kyiv.drive.kyiv_drive;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cache.annotation.EnableCaching;

import java.time.ZoneId;
import java.util.TimeZone;

@SpringBootApplication
@EnableCaching
public class KyivDriveApplication {

    static {
        TimeZone.setDefault(TimeZone.getTimeZone(ZoneId.of("Europe/Kyiv")));
    }

    public static void main(String[] args) {
        SpringApplication.run(KyivDriveApplication.class, args);
    }

}
