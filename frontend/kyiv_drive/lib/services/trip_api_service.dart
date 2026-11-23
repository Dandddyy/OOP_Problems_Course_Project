import 'package:dio/dio.dart';

import '../core/constants/api_constants.dart';
import '../models/trip_model.dart';

class TripApiService {
  final Dio _dio;

  TripApiService(this._dio);

  Future<TripCreateResponseModel> publishTrip(
    CreateTripRequestModel request,
  ) async {
    final response = await _dio.post(
      ApiConstants.tripEndpoint,
      data: request.toJson(),
    );
    return TripCreateResponseModel.fromJson(_jsonObject(response.data));
  }
}

Map<String, dynamic> _jsonObject(Object? data) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  throw const FormatException('Expected a JSON object response');
}
