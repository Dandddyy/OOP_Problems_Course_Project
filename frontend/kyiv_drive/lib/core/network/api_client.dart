import 'package:dio/dio.dart';
import 'api_transport.dart';
import 'auth_interceptor.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();

  factory ApiClient() {
    return _instance;
  }

  late final Dio dio;

  ApiClient._internal() {
    dio = createApiTransport();
    dio.interceptors.add(AuthInterceptor());
  }
}
