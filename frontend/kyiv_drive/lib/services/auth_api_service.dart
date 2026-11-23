import 'package:dio/dio.dart';

import '../core/constants/api_constants.dart';
import '../core/network/api_transport.dart';
import '../models/auth_model.dart';
import 'device_context_service.dart';

class AuthApiService {
  final Dio _dio;
  final DeviceContextService _deviceContextService;

  AuthApiService(this._dio, {DeviceContextService? deviceContextService})
    : _deviceContextService = deviceContextService ?? DeviceContextService();

  factory AuthApiService.forTokenRefresh() {
    return AuthApiService(createApiTransport());
  }

  Future<AuthTokens> googleLogin(GoogleLoginRequest request) async {
    final data = await _withDevice(request.toJson());
    final response = await _dio.post(
      ApiConstants.googleLoginEndpoint,
      data: data,
    );
    return AuthTokens.fromJson(_jsonObject(response.data));
  }

  Future<AuthTokens> googleRegister(GoogleRegisterRequest request) async {
    final data = await _withDevice(request.toJson());
    final response = await _dio.post(
      ApiConstants.googleRegisterEndpoint,
      data: data,
    );
    return AuthTokens.fromJson(_jsonObject(response.data));
  }

  Future<AuthTokens> login(LoginRequest request) async {
    final data = await _withDevice(request.toJson());
    final response = await _dio.post(ApiConstants.loginEndpoint, data: data);
    return AuthTokens.fromJson(_jsonObject(response.data));
  }

  Future<AuthMessageResponse> sendRegistrationCode(
    PreRegisterRequest request,
  ) async {
    final response = await _dio.post(
      ApiConstants.sendRegistrationCodeEndpoint,
      data: request.toJson(),
    );
    return AuthMessageResponse.fromJson(_jsonObject(response.data));
  }

  Future<AuthTokens> register(RegisterRequest request) async {
    final data = await _withDevice(request.toJson());
    final response = await _dio.post(ApiConstants.registerEndpoint, data: data);
    return AuthTokens.fromJson(_jsonObject(response.data));
  }

  Future<AuthMessageResponse> sendCode(SendCodeRequest request) async {
    final response = await _dio.post(
      ApiConstants.sendCodeEndpoint,
      data: request.toJson(),
    );
    return AuthMessageResponse.fromJson(_jsonObject(response.data));
  }

  Future<PasswordResetGrant> verifyCode(VerifyCodeRequest request) async {
    final response = await _dio.post(
      ApiConstants.verifyCodeEndpoint,
      data: request.toJson(),
    );
    return PasswordResetGrant.fromJson(_jsonObject(response.data));
  }

  Future<AuthTokens> resetPassword(ResetPasswordRequest request) async {
    final data = await _withDevice(request.toJson());
    final response = await _dio.post(
      ApiConstants.resetPasswordEndpoint,
      data: data,
    );
    return AuthTokens.fromJson(_jsonObject(response.data));
  }

  Future<AccessTokenResponse> switchMode(SwitchModeRequest request) async {
    final response = await _dio.post(
      ApiConstants.switchModeEndpoint,
      data: request.toJson(),
    );
    return AccessTokenResponse.fromJson(_jsonObject(response.data));
  }

  Future<AuthTokens> refreshToken(RefreshTokenRequest request) async {
    final data = await _withDevice(request.toJson());
    final response = await _dio.post(ApiConstants.refreshEndpoint, data: data);
    return AuthTokens.fromJson(_jsonObject(response.data));
  }

  Future<void> logout({required String accessToken}) async {
    await _dio.post<void>(
      ApiConstants.logoutEndpoint,
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
  }

  Future<CurrentUserResponse> getCurrentUser({String? accessToken}) async {
    final response = await _dio.get(
      ApiConstants.currentUserEndpoint,
      options: accessToken == null
          ? null
          : Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return CurrentUserResponse.fromJson(_jsonObject(response.data));
  }

  Future<Map<String, dynamic>> _withDevice(Map<String, dynamic> data) async {
    final device = await _deviceContextService.build();
    return {...data, 'device': device.toJson()};
  }
}

Map<String, dynamic> _jsonObject(Object? data) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);

  throw const FormatException('Expected a JSON object response');
}
