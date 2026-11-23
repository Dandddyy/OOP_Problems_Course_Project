import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';

class MapConfigService {
  final Dio _dio;

  MapConfigService(this._dio);

  Future<Map<String, dynamic>> fetchConfig() async {
    final response = await _dio.get(ApiConstants.configMapEndpoint);

    if (response.data is! Map<String, dynamic>) {
      throw Exception("Invalid map config response");
    }

    return Map<String, dynamic>.from(response.data);
  }
}