package ua.kyiv.drive.kyiv_drive.auth;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;

public final class TokenHash {

    private TokenHash() {
    }

    public static String sha256(String token) {
        try {
            byte[] hash = MessageDigest.getInstance("SHA-256")
                    .digest(token.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hash);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 is unavailable", e);
        }
    }

    public static boolean matches(String token, String expectedHexHash) {
        if (expectedHexHash == null) {
            return false;
        }

        byte[] actual = sha256(token).getBytes(StandardCharsets.US_ASCII);
        byte[] expected = expectedHexHash.getBytes(StandardCharsets.US_ASCII);
        return MessageDigest.isEqual(actual, expected);
    }
}
