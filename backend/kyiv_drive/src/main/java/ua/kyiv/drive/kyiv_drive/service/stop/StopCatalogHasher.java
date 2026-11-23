package ua.kyiv.drive.kyiv_drive.service.stop;

import org.locationtech.jts.geom.Point;
import org.springframework.stereotype.Component;
import ua.kyiv.drive.kyiv_drive.entity.Stop;

import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Collection;
import java.util.Comparator;

@Component
public class StopCatalogHasher {

    public String hash(Collection<Stop> stops) {
        MessageDigest digest = Sha256Support.newDigest();

        stops.stream()
                .sorted(Comparator.comparing(Stop::getOsmId).thenComparing(Stop::getId))
                .forEach(stop -> updateDigest(digest, stop));

        return Sha256Support.toHex(digest.digest());
    }

    private void updateDigest(MessageDigest digest, Stop stop) {
        updateLong(digest, stop.getOsmId());
        updateLong(digest, stop.getId().getMostSignificantBits());
        updateLong(digest, stop.getId().getLeastSignificantBits());
        digest.update((byte) (Boolean.TRUE.equals(stop.getIsActive()) ? 1 : 0));
        updateString(digest, stop.getName());

        Point location = stop.getLocation();
        updateLong(digest, Double.doubleToLongBits(location.getX()));
        updateLong(digest, Double.doubleToLongBits(location.getY()));
    }

    private void updateString(MessageDigest digest, String value) {
        if (value == null) {
            updateLong(digest, -1L);
            return;
        }

        byte[] bytes = value.getBytes(StandardCharsets.UTF_8);
        updateLong(digest, bytes.length);
        digest.update(bytes);
    }

    private void updateLong(MessageDigest digest, long value) {
        digest.update(ByteBuffer.allocate(Long.BYTES).putLong(value).array());
    }
}
