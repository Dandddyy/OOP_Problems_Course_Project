package ua.kyiv.drive.kyiv_drive.service;

import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.api.client.json.gson.GsonFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.security.GeneralSecurityException;
import java.util.Collections;

@Service
public class GoogleIdTokenService {

    private final GoogleIdTokenVerifier verifier;

    public GoogleIdTokenService(@Value("${google.client.id}") String googleClientId) {
        this.verifier = new GoogleIdTokenVerifier.Builder(new NetHttpTransport(), new GsonFactory())
                .setAudience(Collections.singletonList(googleClientId))
                .build();
    }

    public GoogleIdToken.Payload verify(String token) {
        final GoogleIdToken idToken;
        try {
            idToken = verifier.verify(token);
        } catch (GeneralSecurityException | IOException e) {
            throw new IllegalArgumentException("Google token verification failed", e);
        }

        if (idToken == null) {
            throw new IllegalArgumentException("Invalid Google ID token");
        }
        if (!Boolean.TRUE.equals(idToken.getPayload().getEmailVerified())) {
            throw new IllegalArgumentException("Email not verified by Google");
        }
        return idToken.getPayload();
    }
}
