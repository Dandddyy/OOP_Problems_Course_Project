import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/auth_model.dart';

class StorageService {
  final _storage = const FlutterSecureStorage();

  static const _credentialBundleKey = 'auth_credentials_v2';
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _installationIdKey = 'installation_id';
  static const _minimumAppVersionKeyPrefix = 'minimum_app_version_';

  Future<void> saveAuthSession(AuthTokens credentials) async {
    final bundle = jsonEncode({
      'version': 2,
      'credentials': credentials.toJson(),
    });
    await _storage.write(key: _credentialBundleKey, value: bundle);
  }

  Future<AuthTokens?> getAuthSession() async {
    final raw = await _storage.read(key: _credentialBundleKey);
    if (raw == null) return null;

    final decoded = jsonDecode(raw);
    if (decoded is! Map || decoded['version'] != 2) {
      throw const FormatException('Unsupported credential bundle');
    }
    final credentials = decoded['credentials'];
    if (credentials is! Map) {
      throw const FormatException('Credential bundle is malformed');
    }
    return AuthTokens.fromJson(Map<String, dynamic>.from(credentials));
  }

  Future<String?> getAccessToken() async {
    return (await getAuthSession())?.accessToken;
  }

  Future<String?> getRefreshToken() async {
    return (await getAuthSession())?.refreshToken;
  }

  Future<void> saveInstallationId(String installationId) async {
    await _storage.write(key: _installationIdKey, value: installationId);
  }

  Future<String?> getInstallationId() async {
    return await _storage.read(key: _installationIdKey);
  }

  Future<String?> getMinimumAppVersion(String platform) =>
      _storage.read(key: '$_minimumAppVersionKeyPrefix$platform');

  Future<void> saveMinimumAppVersion(String platform, String version) =>
      _storage.write(
        key: '$_minimumAppVersionKeyPrefix$platform',
        value: version,
      );

  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _credentialBundleKey),
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
    ]);
  }
}
