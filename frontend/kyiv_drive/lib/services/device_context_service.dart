import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/auth_model.dart';
import '../utils/uuid.dart';
import 'storage_service.dart';

typedef DeviceNameLoader = Future<String> Function();
typedef AppVersionLoader = Future<String> Function();

class DeviceContextService {
  static String get currentPlatform => Platform.isIOS ? 'IOS' : 'ANDROID';

  final StorageService _storageService;
  final Random _random;
  final DeviceInfoPlugin _deviceInfoPlugin;
  final DeviceNameLoader? _deviceNameLoader;
  final AppVersionLoader? _appVersionLoader;

  DeviceContextService({
    StorageService? storageService,
    Random? random,
    DeviceInfoPlugin? deviceInfoPlugin,
    DeviceNameLoader? deviceNameLoader,
    AppVersionLoader? appVersionLoader,
  }) : _storageService = storageService ?? StorageService(),
       _random = random ?? Random.secure(),
       _deviceInfoPlugin = deviceInfoPlugin ?? DeviceInfoPlugin(),
       _deviceNameLoader = deviceNameLoader,
       _appVersionLoader = appVersionLoader;

  Future<DeviceContext> build() async {
    var installationId = await _storageService.getInstallationId();
    if (installationId == null || !_isUuid(installationId)) {
      installationId = generateUuidV4(random: _random);
      await _storageService.saveInstallationId(installationId);
    }

    final deviceName = await _loadDeviceName();
    final appVersion = await loadAppVersion();

    return DeviceContext(
      installationId: installationId,
      deviceName: deviceName,
      platform: currentPlatform,
      appVersion: appVersion,
    );
  }

  Future<String> _loadDeviceName() async {
    final fallback = Platform.isIOS ? 'iOS device' : 'Android device';

    try {
      final name = _deviceNameLoader != null
          ? await _deviceNameLoader()
          : await _readPlatformDeviceName();
      return _normalizeDeviceName(name, fallback);
    } catch (_) {
      return fallback;
    }
  }

  Future<String> _readPlatformDeviceName() async {
    if (Platform.isIOS) {
      final info = await _deviceInfoPlugin.iosInfo;
      final assignedName = info.name.trim();
      if (_isUsefulDeviceName(assignedName) &&
          assignedName.toLowerCase() != 'iphone' &&
          assignedName.toLowerCase() != 'ipad') {
        return assignedName;
      }
      return info.modelName;
    }

    final info = await _deviceInfoPlugin.androidInfo;
    final assignedName = info.name.trim();
    if (_isUsefulDeviceName(assignedName)) {
      return assignedName;
    }

    final manufacturer = info.manufacturer.trim();
    final model = info.model.trim();
    if (!_isUsefulDeviceName(manufacturer)) {
      return model;
    }
    if (!_isUsefulDeviceName(model)) {
      return manufacturer;
    }
    if (model.toLowerCase().startsWith(manufacturer.toLowerCase())) {
      return model;
    }
    return '$manufacturer $model';
  }

  Future<String> loadAppVersion() async {
    try {
      final version = _appVersionLoader != null
          ? await _appVersionLoader()
          : await _readPackageVersion();
      return _normalizeMetadata(version, 'unknown', 32);
    } catch (_) {
      return 'unknown';
    }
  }

  Future<String> _readPackageVersion() async {
    final info = await PackageInfo.fromPlatform();
    final version = info.version.trim();
    final buildNumber = info.buildNumber.trim();
    return buildNumber.isEmpty ? version : '$version+$buildNumber';
  }

  String _normalizeDeviceName(String value, String fallback) {
    return _normalizeMetadata(value, fallback, 120);
  }

  String _normalizeMetadata(String value, String fallback, int maxLength) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (!_isUsefulDeviceName(normalized)) {
      return fallback;
    }
    if (normalized.length <= maxLength) {
      return normalized;
    }

    var end = maxLength;
    final lastCodeUnit = normalized.codeUnitAt(end - 1);
    if (lastCodeUnit >= 0xd800 && lastCodeUnit <= 0xdbff) {
      end--;
    }
    return normalized.substring(0, end).trimRight();
  }

  bool _isUsefulDeviceName(String value) {
    return value.isNotEmpty && value.toLowerCase() != 'unknown';
  }

  bool _isUuid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }
}
