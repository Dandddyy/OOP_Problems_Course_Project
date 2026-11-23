import 'package:dio/dio.dart';

import '../core/constants/api_constants.dart';
import '../models/device_session_model.dart';

class SessionApiService {
  final Dio _dio;

  SessionApiService(this._dio);

  Future<List<DeviceSessionModel>> getSessions() async {
    final response = await _dio.get(ApiConstants.sessionsEndpoint);
    final data = response.data;
    if (data is! List) {
      throw const FormatException('Expected a JSON array of sessions');
    }

    return data
        .map((item) => DeviceSessionModel.fromJson(_jsonObject(item)))
        .toList();
  }

  Future<void> deleteSession(String sessionId) async {
    await _dio.delete<void>('${ApiConstants.sessionsEndpoint}/$sessionId');
  }

  Future<void> logoutOthers() async {
    await _dio.post<void>(ApiConstants.logoutOthersEndpoint);
  }
}

Map<String, dynamic> _jsonObject(Object? data) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);

  throw const FormatException('Expected a JSON object response');
}
