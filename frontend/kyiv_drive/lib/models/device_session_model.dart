import 'auth_model.dart';

enum DeviceSessionPlatform { android, ios }

class DeviceSessionModel {
  final String id;
  final String deviceName;
  final DeviceSessionPlatform platform;
  final String appVersion;
  final AuthUserMode currentMode;
  final DateTime createdAt;
  final DateTime lastUsedAt;
  final DateTime idleExpiresAt;
  final bool current;

  const DeviceSessionModel({
    required this.id,
    required this.deviceName,
    required this.platform,
    required this.appVersion,
    required this.currentMode,
    required this.createdAt,
    required this.lastUsedAt,
    required this.idleExpiresAt,
    required this.current,
  });

  factory DeviceSessionModel.fromJson(Map<String, dynamic> json) {
    return DeviceSessionModel(
      id: _requiredString(json, 'id'),
      deviceName: _requiredString(json, 'deviceName'),
      platform: switch (_requiredString(json, 'platform')) {
        'ANDROID' => DeviceSessionPlatform.android,
        'IOS' => DeviceSessionPlatform.ios,
        _ => throw const FormatException(
          'Response field "platform" has an unsupported value',
        ),
      },
      appVersion: _requiredString(json, 'appVersion'),
      currentMode: switch (_requiredString(json, 'currentMode')) {
        'DRIVER' => AuthUserMode.driver,
        'PASSENGER' => AuthUserMode.passenger,
        _ => throw const FormatException(
          'Response field "currentMode" has an unsupported value',
        ),
      },
      createdAt: _requiredInstant(json, 'createdAt'),
      lastUsedAt: _requiredInstant(json, 'lastUsedAt'),
      idleExpiresAt: _requiredInstant(json, 'idleExpiresAt'),
      current: _requiredBool(json, 'current'),
    );
  }
}

String _requiredString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Response field "$field" must be a non-empty string');
}

DateTime _requiredInstant(Map<String, dynamic> json, String field) {
  final value = _requiredString(json, field);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Response field "$field" must be an ISO-8601 date');
  }
  return parsed.toUtc();
}

bool _requiredBool(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is bool) return value;
  throw FormatException('Response field "$field" must be a boolean');
}
