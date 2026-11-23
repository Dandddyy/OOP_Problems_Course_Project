import 'dart:ui';

import 'package:dio/dio.dart';

import '../../models/auth_model.dart';
import '../../services/auth_api_service.dart';
import '../../services/storage_service.dart';
import '../../services/user_session.dart';
import '../constants/api_constants.dart';
import 'api_error_codes.dart';
import 'api_transport.dart';

class AuthInterceptor extends QueuedInterceptor {
  static const Set<String> _publicAuthEndpoints = {
    ApiConstants.loginEndpoint,
    ApiConstants.registerEndpoint,
    ApiConstants.googleLoginEndpoint,
    ApiConstants.googleRegisterEndpoint,
    ApiConstants.refreshEndpoint,
    ApiConstants.sendRegistrationCodeEndpoint,
    ApiConstants.sendCodeEndpoint,
    ApiConstants.verifyCodeEndpoint,
    ApiConstants.resetPasswordEndpoint,
  };

  final AuthApiService _refreshApiService;
  final StorageService _storageService;
  final UserSession _userSession;
  late final Dio _replayDio = createApiTransport();

  AuthInterceptor({
    AuthApiService? refreshApiService,
    StorageService? storageService,
    UserSession? userSession,
  }) : _refreshApiService =
           refreshApiService ?? AuthApiService.forTokenRefresh(),
       _storageService = storageService ?? StorageService(),
       _userSession = userSession ?? UserSession();

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final locale = PlatformDispatcher.instance.locale.languageCode;
    options.headers['Accept-Language'] = locale;

    if (!_isPublicAuthRequest(options)) {
      final token = await _storageService.getAccessToken();
      if (token != null && !options.headers.containsKey('Authorization')) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (isAppUpdateRequiredError(err)) {
      await _userSession.requireAppUpdate(err);
      handler.next(err);
      return;
    }

    if (err.response?.statusCode != 401 ||
        _isPublicAuthRequest(err.requestOptions)) {
      handler.next(err);
      return;
    }

    try {
      final currentToken = await _storageService.getAccessToken();
      final requestAuthHeader =
          err.requestOptions.headers['Authorization'] as String?;
      final requestToken = requestAuthHeader?.replaceFirst('Bearer ', '');

      if (currentToken != null &&
          requestToken != null &&
          currentToken != requestToken) {
        await _retryWithToken(err, currentToken, handler);
        return;
      }

      final refreshToken = await _storageService.getRefreshToken();
      if (refreshToken == null) {
        await _userSession.logout();
        handler.next(err);
        return;
      }

      late final AuthTokens tokens;
      try {
        tokens = await _userSession.refreshCurrentSession(
          expectedRefreshToken: refreshToken,
          refreshSession: (currentRefreshToken) =>
              _refreshApiService.refreshToken(
                RefreshTokenRequest(refreshToken: currentRefreshToken),
              ),
        );
      } on DioException catch (refreshError) {
        if (isAppUpdateRequiredError(refreshError)) {
          await _userSession.requireAppUpdate(refreshError);
          handler.reject(refreshError);
          return;
        }
        if (_isRejectedRefresh(refreshError)) {
          await _userSession.logout();
          handler.next(err);
        } else {
          handler.reject(refreshError);
        }
        return;
      }

      await _retryWithToken(err, tokens.accessToken, handler);
    } on DioException catch (unexpectedDioError) {
      handler.reject(unexpectedDioError);
    } catch (unexpectedError, stackTrace) {
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          error: unexpectedError,
          stackTrace: stackTrace,
          message: 'Unable to refresh the current session',
        ),
      );
    }
  }

  bool _isRejectedRefresh(DioException error) {
    final statusCode = error.response?.statusCode;
    return statusCode == 401 || statusCode == 403;
  }

  bool _isPublicAuthRequest(RequestOptions options) {
    return _publicAuthEndpoints.contains(options.uri.path);
  }

  Future<void> _retryWithToken(
    DioException originalError,
    String accessToken,
    ErrorInterceptorHandler handler,
  ) async {
    final original = originalError.requestOptions;
    final request = original.copyWith(
      headers: {...original.headers, 'Authorization': 'Bearer $accessToken'},
    );
    try {
      final response = await _replayDio.fetch(request);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.reject(retryError);
    }
  }
}
