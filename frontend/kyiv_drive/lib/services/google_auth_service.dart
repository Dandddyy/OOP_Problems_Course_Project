import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/constants/auth_constants.dart';
import '../models/auth_model.dart';
import '../services/auth_api_service.dart';

sealed class GoogleAuthResult {
  const GoogleAuthResult();
}

final class GoogleAuthCancelled extends GoogleAuthResult {
  const GoogleAuthCancelled();
}

final class GoogleLoginSuccess extends GoogleAuthResult {
  final AuthTokens tokens;

  const GoogleLoginSuccess({required this.tokens});
}

final class GoogleRegistrationRequired extends GoogleAuthResult {
  final String email;
  final String name;
  final String? photoUrl;
  final String idToken;

  const GoogleRegistrationRequired({
    required this.email,
    required this.name,
    required this.photoUrl,
    required this.idToken,
  });
}

class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  Future<GoogleSignInAccount?> signIn() async {
    try {
      await _googleSignIn.initialize(
        serverClientId: AuthConstants.googleWebClientId,
      );

      return await _googleSignIn.authenticate();
    } catch (error) {
      print('Google Sign In Error: $error');
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.disconnect();
  }

  Future<GoogleAuthResult> handleSignIn({
    required AuthApiService authApiService,
  }) async {
    final googleUser = await signIn();

    if (googleUser == null) {
      return const GoogleAuthCancelled();
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;

    if (idToken == null) {
      return const GoogleAuthCancelled();
    }

    try {
      final tokens = await authApiService.googleLogin(
        GoogleLoginRequest(idToken: idToken, avatarUrl: googleUser.photoUrl),
      );

      return GoogleLoginSuccess(tokens: tokens);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        final errorResponse = AuthErrorResponse.tryParse(error.response?.data);
        if (errorResponse?.needRegistration != true) rethrow;

        return GoogleRegistrationRequired(
          email: googleUser.email,
          name: errorResponse?.firstName ?? '',
          photoUrl: googleUser.photoUrl,
          idToken: idToken,
        );
      }

      rethrow;
    }
  }
}
