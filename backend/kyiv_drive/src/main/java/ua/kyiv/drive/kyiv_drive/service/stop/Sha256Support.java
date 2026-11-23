package ua.kyiv.drive.kyiv_drive.service.stop;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;

final class Sha256Support {

    private Sha256Support() {
    }

    static MessageDigest newDigest() {
        try {
            return MessageDigest.getInstance("SHA-256");
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 is not available", exception);
        }
    }

    static String hash(byte[] value) {
        return toHex(newDigest().digest(value));
    }

    static String toHex(byte[] value) {
        return HexFormat.of().formatHex(value);
    }
}
