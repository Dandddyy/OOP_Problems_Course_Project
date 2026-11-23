enum AuthUserMode {
  driver,
  passenger;

  String get apiValue => name.toUpperCase();
}

enum AuthUserRole {
  user,
  admin;

  String get apiValue => name.toUpperCase();
}

class DeviceContext {
  final String installationId;
  final String deviceName;
  final String platform;
  final String appVersion;

  const DeviceContext({
    required this.installationId,
    required this.deviceName,
    required this.platform,
    required this.appVersion,
  });

  Map<String, dynamic> toJson() => {
    'installationId': installationId,
    'deviceName': deviceName,
    'platform': platform,
    'appVersion': appVersion,
  };
}

class AuthTokens {
  final String tokenType;
  final String accessToken;
  final DateTime accessTokenExpiresAt;
  final String refreshToken;
  final DateTime refreshTokenExpiresAt;
  final SessionContext session;
  final CurrentUserProfile user;

  const AuthTokens({
    required this.tokenType,
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshToken,
    required this.refreshTokenExpiresAt,
    required this.session,
    required this.user,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      tokenType: _requiredBearerTokenType(json),
      accessToken: _requiredString(json, 'accessToken'),
      accessTokenExpiresAt: _requiredInstant(json, 'accessTokenExpiresAt'),
      refreshToken: _requiredString(json, 'refreshToken'),
      refreshTokenExpiresAt: _requiredInstant(json, 'refreshTokenExpiresAt'),
      session: SessionContext.fromJson(_requiredObject(json, 'session')),
      user: CurrentUserProfile.fromJson(_requiredObject(json, 'user')),
    );
  }

  Map<String, dynamic> toJson() => {
    'tokenType': tokenType,
    'accessToken': accessToken,
    'accessTokenExpiresAt': accessTokenExpiresAt.toUtc().toIso8601String(),
    'refreshToken': refreshToken,
    'refreshTokenExpiresAt': refreshTokenExpiresAt.toUtc().toIso8601String(),
    'session': session.toJson(),
    'user': user.toJson(),
  };

  AuthTokens withAccessToken(AccessTokenResponse response) {
    return AuthTokens(
      tokenType: response.tokenType,
      accessToken: response.accessToken,
      accessTokenExpiresAt: response.accessTokenExpiresAt,
      refreshToken: refreshToken,
      refreshTokenExpiresAt: refreshTokenExpiresAt,
      session: response.session,
      user: user,
    );
  }

  AuthTokens withCurrentUser(CurrentUserResponse response) {
    return AuthTokens(
      tokenType: tokenType,
      accessToken: accessToken,
      accessTokenExpiresAt: accessTokenExpiresAt,
      refreshToken: refreshToken,
      refreshTokenExpiresAt: refreshTokenExpiresAt,
      session: response.session,
      user: response.user,
    );
  }
}

class AccessTokenResponse {
  final String tokenType;
  final String accessToken;
  final DateTime accessTokenExpiresAt;
  final SessionContext session;

  const AccessTokenResponse({
    required this.tokenType,
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.session,
  });

  factory AccessTokenResponse.fromJson(Map<String, dynamic> json) {
    return AccessTokenResponse(
      tokenType: _requiredBearerTokenType(json),
      accessToken: _requiredString(json, 'accessToken'),
      accessTokenExpiresAt: _requiredInstant(json, 'accessTokenExpiresAt'),
      session: SessionContext.fromJson(_requiredObject(json, 'session')),
    );
  }
}

class CurrentUserResponse {
  final SessionContext session;
  final CurrentUserProfile user;

  const CurrentUserResponse({required this.session, required this.user});

  factory CurrentUserResponse.fromJson(Map<String, dynamic> json) {
    return CurrentUserResponse(
      session: SessionContext.fromJson(_requiredObject(json, 'session')),
      user: CurrentUserProfile.fromJson(_requiredObject(json, 'user')),
    );
  }
}

class SessionContext {
  final String id;
  final AuthUserMode currentMode;

  const SessionContext({required this.id, required this.currentMode});

  factory SessionContext.fromJson(Map<String, dynamic> json) {
    final rawMode = _requiredString(json, 'currentMode');
    final currentMode = switch (rawMode) {
      'DRIVER' => AuthUserMode.driver,
      'PASSENGER' => AuthUserMode.passenger,
      _ => throw const FormatException(
        'Response field "currentMode" has an unsupported value',
      ),
    };
    return SessionContext(
      id: _requiredString(json, 'id'),
      currentMode: currentMode,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'currentMode': currentMode.apiValue,
  };
}

class CurrentUserProfile {
  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final String? bio;
  final bool tutorialCompleted;
  final AuthUserRole role;

  const CurrentUserProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.avatarUrl,
    required this.bio,
    required this.tutorialCompleted,
    required this.role,
  });

  factory CurrentUserProfile.fromJson(Map<String, dynamic> json) {
    final rawRole = _requiredString(json, 'role');
    final role = switch (rawRole) {
      'USER' => AuthUserRole.user,
      'ADMIN' => AuthUserRole.admin,
      _ => throw const FormatException(
        'Response field "role" has an unsupported value',
      ),
    };
    return CurrentUserProfile(
      id: _requiredString(json, 'id'),
      email: _requiredString(json, 'email'),
      name: _requiredString(json, 'name'),
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
      tutorialCompleted: _requiredBool(json, 'tutorialCompleted'),
      role: role,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'avatarUrl': avatarUrl,
    'bio': bio,
    'tutorialCompleted': tutorialCompleted,
    'role': role.apiValue,
  };
}

class LoginRequest {
  final String email;
  final String password;

  const LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}

class GoogleLoginRequest {
  final String idToken;
  final String? avatarUrl;

  const GoogleLoginRequest({required this.idToken, this.avatarUrl});

  Map<String, dynamic> toJson() => {'idToken': idToken, 'avatarUrl': avatarUrl};
}

class GoogleRegisterRequest {
  final String idToken;
  final String name;
  final AuthUserMode currentMode;
  final String? avatarUrl;

  const GoogleRegisterRequest({
    required this.idToken,
    required this.name,
    required this.currentMode,
    this.avatarUrl,
  });

  Map<String, dynamic> toJson() => {
    'idToken': idToken,
    'name': name,
    'avatarUrl': avatarUrl,
    'currentMode': currentMode.apiValue,
  };
}

class PreRegisterRequest {
  final String name;
  final String email;
  final String password;

  const PreRegisterRequest({
    required this.name,
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'password': password,
  };
}

class RegisterRequest {
  final String name;
  final String email;
  final String password;
  final AuthUserMode currentMode;
  final String code;

  const RegisterRequest({
    required this.name,
    required this.email,
    required this.password,
    required this.currentMode,
    required this.code,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'password': password,
    'code': code,
    'currentMode': currentMode.apiValue,
  };
}

class SendCodeRequest {
  final String email;

  const SendCodeRequest({required this.email});

  Map<String, dynamic> toJson() => {'email': email};
}

class VerifyCodeRequest {
  final String email;
  final String code;

  const VerifyCodeRequest({required this.email, required this.code});

  Map<String, dynamic> toJson() => {'email': email, 'code': code};
}

class ResetPasswordRequest {
  final String newPassword;
  final String passwordResetToken;

  const ResetPasswordRequest({
    required this.newPassword,
    required this.passwordResetToken,
  });

  Map<String, dynamic> toJson() => {
    'newPassword': newPassword,
    'passwordResetToken': passwordResetToken,
  };
}

class SwitchModeRequest {
  final AuthUserMode targetMode;

  const SwitchModeRequest({required this.targetMode});

  Map<String, dynamic> toJson() => {'targetMode': targetMode.apiValue};
}

class RefreshTokenRequest {
  final String refreshToken;

  const RefreshTokenRequest({required this.refreshToken});

  Map<String, dynamic> toJson() => {'refreshToken': refreshToken};
}

class AuthMessageResponse {
  final String message;

  const AuthMessageResponse({required this.message});

  factory AuthMessageResponse.fromJson(Map<String, dynamic> json) {
    return AuthMessageResponse(message: _requiredString(json, 'message'));
  }
}

class PasswordResetGrant {
  final String passwordResetToken;
  final DateTime expiresAt;

  const PasswordResetGrant({
    required this.passwordResetToken,
    required this.expiresAt,
  });

  factory PasswordResetGrant.fromJson(Map<String, dynamic> json) {
    return PasswordResetGrant(
      passwordResetToken: _requiredString(json, 'passwordResetToken'),
      expiresAt: _requiredInstant(json, 'expiresAt'),
    );
  }
}

class AuthErrorResponse {
  final String? type;
  final String? field;
  final String? message;
  final bool showUser;
  final bool needRegistration;
  final String? firstName;

  const AuthErrorResponse({
    this.type,
    this.field,
    this.message,
    required this.showUser,
    required this.needRegistration,
    this.firstName,
  });

  static AuthErrorResponse? tryParse(Object? data) {
    if (data is! Map) return null;

    final json = Map<String, dynamic>.from(data);
    return AuthErrorResponse(
      type: json['type'] as String?,
      field: json['field'] as String?,
      message: json['message'] as String?,
      showUser: json['showUser'] == true,
      needRegistration: json['needRegistration'] == true,
      firstName: json['firstName'] as String?,
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;

  throw FormatException('Response field "$key" must be a non-empty string');
}

Map<String, dynamic> _requiredObject(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);

  throw FormatException('Response field "$key" must be an object');
}

String _requiredBearerTokenType(Map<String, dynamic> json) {
  final tokenType = _requiredString(json, 'tokenType');
  if (tokenType != 'Bearer') {
    throw const FormatException('Response field "tokenType" must be "Bearer"');
  }
  return tokenType;
}

DateTime _requiredInstant(Map<String, dynamic> json, String key) {
  final raw = _requiredString(json, key);
  final value = DateTime.tryParse(raw);
  if (value == null || !value.isUtc) {
    throw FormatException('Response field "$key" must be a UTC timestamp');
  }
  return value;
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;

  throw FormatException('Response field "$key" must be a boolean');
}
