import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/app_version.dart';
import '../models/auth_model.dart';
import '../core/network/api_client.dart';
import '../core/network/api_error_codes.dart';
import 'auth_api_service.dart';
import 'device_context_service.dart';
import 'home_map_startup.dart';
import 'map_configuration.dart';
import 'storage_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated, appUpdateRequired }

enum AppMode { driver, passenger }

typedef RefreshSession = Future<AuthTokens> Function(String refreshToken);
typedef LoadCurrentUser = Future<CurrentUserResponse> Function();

class UserSession extends ChangeNotifier {
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;
  UserSession._internal();

  final _storageService = StorageService();
  Future<void> _credentialWriteTail = Future<void>.value();
  Future<AuthTokens>? _refreshInFlight;
  int? _refreshInFlightEpoch;
  int _sessionEpoch = 0;
  HomeMapStart? _loginMapStart;

  String? userId;
  String? email;
  String? name;
  AuthUserRole? role;

  AppMode currentMode = AppMode.passenger;

  bool? tutorialCompleted;
  String? avatarUrl;

  final ValueNotifier<AuthStatus> authStatusNotifier = ValueNotifier(
    AuthStatus.unknown,
  );

  AuthStatus get status => authStatusNotifier.value;

  set _status(AuthStatus newStatus) {
    authStatusNotifier.value = newStatus;
  }

  bool _shouldShowWelcome = false;

  bool get consumeWelcomeEvent {
    if (_shouldShowWelcome) {
      _shouldShowWelcome = false;
      return true;
    }
    return false;
  }

  HomeMapStart? takeLoginMapStart() {
    final start = _loginMapStart;
    _loginMapStart = null;
    return start;
  }

  Future<void> init({
    Future<void> Function()? loadMapConfiguration,
    RefreshSession? refreshSession,
    LoadCurrentUser? loadCurrentUser,
    Duration startupDelay = const Duration(seconds: 1),
  }) async {
    final initEpoch = ++_sessionEpoch;
    takeLoginMapStart()?.tileWarmup?.dispose();
    _status = AuthStatus.unknown;

    final AuthTokens? credentials;

    try {
      final results = await Future.wait([
        _readStartupSession(),
        Future<void>.delayed(startupDelay),
      ]);
      if (initEpoch != _sessionEpoch) return;
      final startup =
          results[0] as ({bool updateRequired, AuthTokens? credentials});
      if (startup.updateRequired) {
        _enterAppUpdateRequired();
        return;
      }
      credentials = startup.credentials;
    } on FormatException {
      if (initEpoch == _sessionEpoch) await logout();
      return;
    } catch (_) {
      if (initEpoch != _sessionEpoch) return;
      _setUnauthenticatedPreservingTokens();
      return;
    }

    if (credentials == null) {
      await logout();
      return;
    }

    if (!_isUsable(credentials.refreshTokenExpiresAt)) {
      await logout();
      return;
    }

    var activeCredentials = credentials;
    final hadUsableAccessToken = _isUsable(credentials.accessTokenExpiresAt);
    final shouldRotateRefreshToken = _expiresWithin(
      credentials.refreshTokenExpiresAt,
      const Duration(minutes: 15),
    );

    if (!hadUsableAccessToken || shouldRotateRefreshToken) {
      final refresh = refreshSession ?? _refreshSession;

      try {
        activeCredentials = await refreshCurrentSession(
          expectedRefreshToken: credentials.refreshToken,
          refreshSession: refresh,
        );
      } on DioException catch (error) {
        if (initEpoch != _sessionEpoch) return;
        if (isAppUpdateRequiredError(error)) {
          await requireAppUpdate(error);
          return;
        }
        if (_isRejectedRefresh(error)) {
          await logout();
          return;
        }

        if (!hadUsableAccessToken) {
          _setUnauthenticatedPreservingTokens();
          return;
        }
      } catch (_) {
        if (initEpoch != _sessionEpoch) return;
        if (!hadUsableAccessToken) {
          _setUnauthenticatedPreservingTokens();
          return;
        }
      }
    }

    if (!_isUsable(activeCredentials.accessTokenExpiresAt)) {
      _setUnauthenticatedPreservingTokens();
      return;
    }
    if (initEpoch != _sessionEpoch) return;

    _applyAuthTokens(activeCredentials);
    try {
      final currentUser = await (loadCurrentUser ?? _loadCurrentUser)();
      if (initEpoch != _sessionEpoch) return;
      _applyCurrentUser(currentUser);
      activeCredentials = activeCredentials.withCurrentUser(currentUser);
      await _writeCredentials(() async {
        if (initEpoch != _sessionEpoch) return;
        await _storageService.saveAuthSession(activeCredentials);
      });
    } catch (_) {
      // A valid credential can still be used while profile data is unavailable.
    }
    if (initEpoch != _sessionEpoch || status != AuthStatus.unknown) {
      return;
    }
    await (loadMapConfiguration ?? MapConfiguration().fetchConfig)();

    if (initEpoch != _sessionEpoch || status != AuthStatus.unknown) {
      return;
    }

    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<({bool updateRequired, AuthTokens? credentials})>
  _readStartupSession() async {
    final cachedVersion = await _storageService.getMinimumAppVersion(
      DeviceContextService.currentPlatform,
    );
    final minimum = cachedVersion == null
        ? null
        : AppVersion.tryParse(cachedVersion);
    if (minimum != null) {
      final installed = AppVersion.tryParse(
        await DeviceContextService().loadAppVersion(),
      );
      if (installed == null || installed.compareTo(minimum) < 0) {
        return (updateRequired: true, credentials: null);
      }
    }
    return (
      updateRequired: false,
      credentials: await _storageService.getAuthSession(),
    );
  }

  Future<AuthTokens> _refreshSession(String refreshToken) {
    return AuthApiService.forTokenRefresh().refreshToken(
      RefreshTokenRequest(refreshToken: refreshToken),
    );
  }

  Future<AuthTokens> refreshCurrentSession({
    String? expectedRefreshToken,
    RefreshSession? refreshSession,
  }) {
    final existingRefresh = _refreshInFlight;
    if (existingRefresh != null && _refreshInFlightEpoch == _sessionEpoch) {
      return existingRefresh;
    }

    final operationEpoch = _sessionEpoch;
    late final Future<AuthTokens> trackedRefresh;
    trackedRefresh =
        _performRefresh(
          operationEpoch: operationEpoch,
          expectedRefreshToken: expectedRefreshToken,
          refreshSession: refreshSession ?? _refreshSession,
        ).whenComplete(() {
          if (identical(_refreshInFlight, trackedRefresh)) {
            _refreshInFlight = null;
            _refreshInFlightEpoch = null;
          }
        });
    _refreshInFlight = trackedRefresh;
    _refreshInFlightEpoch = operationEpoch;
    return trackedRefresh;
  }

  Future<AuthTokens> _performRefresh({
    required int operationEpoch,
    required String? expectedRefreshToken,
    required RefreshSession refreshSession,
  }) async {
    final credentials = await _writeCredentials(_storageService.getAuthSession);
    _ensureCurrentEpoch(operationEpoch);
    if (credentials == null) {
      throw const FormatException('No authenticated session is stored');
    }
    if (expectedRefreshToken != null &&
        expectedRefreshToken != credentials.refreshToken) {
      return credentials;
    }

    final usedRefreshToken = credentials.refreshToken;
    final refreshed = await refreshSession(usedRefreshToken);
    _ensureCurrentEpoch(operationEpoch);

    return _writeCredentials(() async {
      _ensureCurrentEpoch(operationEpoch);
      final current = await _storageService.getAuthSession();
      if (current == null) {
        throw const _StaleSessionOperation();
      }
      if (current.refreshToken != usedRefreshToken) {
        return current;
      }

      final merged = _mergeRefreshResult(current, refreshed);
      _validateCredentials(merged);
      await _storageService.saveAuthSession(merged);
      _applyAuthTokens(merged);
      return merged;
    });
  }

  Future<CurrentUserResponse> _loadCurrentUser() {
    return AuthApiService(ApiClient().dio).getCurrentUser();
  }

  bool _isRejectedRefresh(DioException error) {
    final statusCode = error.response?.statusCode;
    return statusCode == 401 || statusCode == 403;
  }

  bool _isUsable(DateTime expiresAt) {
    return expiresAt.isAfter(DateTime.now().toUtc());
  }

  bool _expiresWithin(DateTime expiresAt, Duration duration) {
    return expiresAt.difference(DateTime.now().toUtc()) <= duration;
  }

  Future<void> loginSuccess(
    AuthTokens tokens, {
    required Future<HomeMapStart> Function() prepareHomeMap,
  }) async {
    if (status == AuthStatus.appUpdateRequired) {
      throw const _StaleSessionOperation();
    }
    final operationEpoch = ++_sessionEpoch;
    HomeMapStart? start;
    try {
      await _persistAndApplyTokens(tokens, operationEpoch);
      _ensureCurrentEpoch(operationEpoch);
      await MapConfiguration().fetchConfig();
      _ensureCurrentEpoch(operationEpoch);
      start = await prepareHomeMap();
      _ensureCurrentEpoch(operationEpoch);
    } catch (_) {
      start?.tileWarmup?.dispose();
      if (operationEpoch == _sessionEpoch) await logout();
      rethrow;
    }

    takeLoginMapStart()?.tileWarmup?.dispose();
    _loginMapStart = start;
    _shouldShowWelcome = true;
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> silentUpdate(AuthTokens tokens) async {
    await _persistAndApplyTokens(tokens, _sessionEpoch);
  }

  Future<void> updateUserProfile(AuthTokens tokens) async {
    await _persistAndApplyTokens(tokens, _sessionEpoch);
    notifyListeners();
  }

  Future<void> updateAccessToken(AccessTokenResponse response) async {
    final operationEpoch = _sessionEpoch;
    await _writeCredentials(() async {
      _ensureCurrentEpoch(operationEpoch);
      if (!_isUsable(response.accessTokenExpiresAt)) {
        throw const FormatException(
          'Mode response contains an expired access token',
        );
      }

      final currentCredentials = await _storageService.getAuthSession();
      if (currentCredentials == null) {
        throw const FormatException('No authenticated session is stored');
      }
      if (currentCredentials.session.id != response.session.id) {
        throw const FormatException('Mode response belongs to another session');
      }

      final updatedCredentials = currentCredentials.withAccessToken(response);
      await _storageService.saveAuthSession(updatedCredentials);
      _applyAuthTokens(updatedCredentials);
    });
    notifyListeners();
  }

  Future<void> _persistAndApplyTokens(
    AuthTokens tokens,
    int operationEpoch,
  ) async {
    await _writeCredentials(() async {
      _ensureCurrentEpoch(operationEpoch);
      _validateCredentials(tokens);
      await _storageService.saveAuthSession(tokens);
      _applyAuthTokens(tokens);
    });
  }

  Future<void> logout({bool deleteRemoteSession = false}) async {
    ++_sessionEpoch;
    String? accessToken;
    _clearSessionData();
    if (status != AuthStatus.appUpdateRequired) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();

    await _writeCredentials(() async {
      if (deleteRemoteSession) {
        try {
          accessToken = await _storageService.getAccessToken();
        } catch (_) {
          accessToken = null;
        }
      }
      await _storageService.clearTokens();
    });

    final tokenToLogout = accessToken;
    if (tokenToLogout != null) {
      try {
        await AuthApiService.forTokenRefresh().logout(
          accessToken: tokenToLogout,
        );
      } catch (_) {
        // Server-side deletion is best-effort; local logout has already completed.
      }
    }
  }

  Future<void> requireAppUpdate(DioException error) {
    // Invalidate pending auth work while the minimum version is persisted.
    ++_sessionEpoch;
    return _writeCredentials(() async {
      final data = error.response?.data;
      final platform = DeviceContextService.currentPlatform;
      final minimum = data is Map && data['platform'] == platform
          ? data['minimumVersion']
          : null;
      if (minimum is String && AppVersion.tryParse(minimum) != null) {
        try {
          await _storageService.saveMinimumAppVersion(platform, minimum.trim());
        } catch (error) {
          debugPrint(
            'Unable to save the minimum app version (${error.runtimeType})',
          );
        }
      }

      _enterAppUpdateRequired();
      try {
        await _storageService.clearTokens();
      } catch (error) {
        debugPrint(
          'Unable to clear tokens after an app update error (${error.runtimeType})',
        );
      }
    });
  }

  void _enterAppUpdateRequired() {
    ++_sessionEpoch;
    _clearSessionData();
    _status = AuthStatus.appUpdateRequired;
    notifyListeners();
  }

  void updateProfileSummary({required String name, String? avatarUrl}) {
    if (status != AuthStatus.authenticated) {
      return;
    }
    this.name = name;
    this.avatarUrl = avatarUrl;
    notifyListeners();
  }

  void _setUnauthenticatedPreservingTokens() {
    ++_sessionEpoch;
    _clearSessionData();
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void _clearSessionData() {
    takeLoginMapStart()?.tileWarmup?.dispose();
    MapConfiguration().clear();

    userId = null;
    name = null;
    email = null;
    role = null;
    tutorialCompleted = null;
    avatarUrl = null;
    currentMode = AppMode.passenger;
    _shouldShowWelcome = false;
  }

  void _applyAuthTokens(AuthTokens credentials) {
    _applyCurrentUser(
      CurrentUserResponse(session: credentials.session, user: credentials.user),
    );
  }

  void _applyCurrentUser(CurrentUserResponse response) {
    userId = response.user.id;
    email = response.user.email;
    name = response.user.name;
    role = response.user.role;
    tutorialCompleted = response.user.tutorialCompleted;
    avatarUrl = response.user.avatarUrl;
    currentMode = response.session.currentMode == AuthUserMode.driver
        ? AppMode.driver
        : AppMode.passenger;
  }

  Future<T> _writeCredentials<T>(Future<T> Function() operation) {
    final previous = _credentialWriteTail;
    final completer = Completer<void>();
    _credentialWriteTail = completer.future;

    return (() async {
      await previous;
      try {
        return await operation();
      } finally {
        completer.complete();
      }
    })();
  }

  void _ensureCurrentEpoch(int expectedEpoch) {
    if (expectedEpoch != _sessionEpoch) {
      throw const _StaleSessionOperation();
    }
  }

  void _validateCredentials(AuthTokens tokens) {
    if (!_isUsable(tokens.accessTokenExpiresAt) ||
        !_isUsable(tokens.refreshTokenExpiresAt)) {
      throw const FormatException('Auth response contains expired tokens');
    }
  }

  AuthTokens _mergeRefreshResult(AuthTokens current, AuthTokens refreshed) {
    if (current.session.id != refreshed.session.id) {
      throw const FormatException(
        'Refresh response belongs to another session',
      );
    }

    if (current.accessTokenExpiresAt.isBefore(refreshed.accessTokenExpiresAt)) {
      return refreshed;
    }

    return AuthTokens(
      tokenType: current.tokenType,
      accessToken: current.accessToken,
      accessTokenExpiresAt: current.accessTokenExpiresAt,
      refreshToken: refreshed.refreshToken,
      refreshTokenExpiresAt: refreshed.refreshTokenExpiresAt,
      session: current.session,
      user: refreshed.user,
    );
  }
}

class _StaleSessionOperation implements Exception {
  const _StaleSessionOperation();
}
