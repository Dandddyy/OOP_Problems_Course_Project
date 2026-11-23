import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants/api_constants.dart';
import '../models/address_model.dart';
import '../models/route_model.dart';
import '../models/route_with_stops_model.dart';

class MapApiService {
  final Dio _dio;

  MapApiService(this._dio);

  Future<AddressModel> reverseGeocode({
    required double lat,
    required double lon,
  }) async {
    final response = await _dio.get(
      ApiConstants.reverseGeocodeEndpoint,
      queryParameters: {
        'lat': lat,
        'lon': lon,
      },
    );

    return AddressModel.fromJson(response.data);
  }

  Future<List<AddressModel>> autocomplete({
    required String text,
  }) async {
    final response = await _dio.get(
      ApiConstants.autocompleteEndpoint,
      queryParameters: {
        'text': text,
      },
    );

    final List<dynamic> data = response.data;
    return data.map((json) => AddressModel.fromJson(json)).toList();
  }

  Future<RouteModel> getRoute({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
  }) async {
    final response = await _dio.post(
      ApiConstants.getRouteEndpoint,
      data: {
        'startLat': startLat,
        'startLon': startLon,
        'endLat': endLat,
        'endLon': endLon,
      },
    );

    return RouteModel.fromJson(response.data);
  }

  Future<RouteWithStopsModel> getRouteWithStops({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
    List<LatLng>? waypoints,
    CancelToken? cancelToken,
  }) async {

    final Map<String, dynamic> requestData = {
      'startLat': startLat,
      'startLon': startLon,
      'endLat': endLat,
      'endLon': endLon,
    };

    if (waypoints != null && waypoints.isNotEmpty) {
      requestData['waypoints'] = waypoints.map((w) => {
        'lat': w.latitude,
        'lon': w.longitude,
      }).toList();
    }

    final response = await _dio.post(
      ApiConstants.getRouteWithStopsEndpoint,
      data: requestData,
      cancelToken: cancelToken,
    );

    return RouteWithStopsModel.fromJson(response.data);
  }
}
