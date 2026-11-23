import 'package:dio/dio.dart';

import '../core/constants/api_constants.dart';
import '../models/trip_search_model.dart';

abstract interface class TripSearchGateway {
  Future<TripSearchPageModel> search(
    TripSearchRequestModel request, {
    CancelToken? cancelToken,
  });
  Future<TripSearchPageModel> getPage(
    String searchId, {
    String? cursor,
    CancelToken? cancelToken,
  });
  Future<TripSearchPageModel> reprioritize(
    String searchId,
    TripSearchPreferencesRequestModel request, {
    CancelToken? cancelToken,
  });
  Future<TripSearchKeepAliveModel> keepAlive(
    String searchId, {
    CancelToken? cancelToken,
  });
}

/// Uses the caller's shared Dio, including authentication and session refresh.
class TripSearchApiService implements TripSearchGateway {
  final Dio _dio;

  TripSearchApiService(this._dio);

  @override
  Future<TripSearchPageModel> search(
    TripSearchRequestModel request, {
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.post(
      ApiConstants.tripSearchEndpoint,
      data: request.toJson(),
      cancelToken: cancelToken,
    );
    return TripSearchPageModel.fromJson(_jsonObject(response.data));
  }

  @override
  Future<TripSearchPageModel> getPage(
    String searchId, {
    String? cursor,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get(
      _searchPath(searchId),
      queryParameters: {'cursor': ?cursor},
      cancelToken: cancelToken,
    );
    return TripSearchPageModel.fromJson(_jsonObject(response.data));
  }

  /// Returns a new or reused opaque result ID, cursor sequence and renewed expiry.
  @override
  Future<TripSearchPageModel> reprioritize(
    String searchId,
    TripSearchPreferencesRequestModel request, {
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.post(
      '${_searchPath(searchId)}/preferences',
      data: request.toJson(),
      cancelToken: cancelToken,
    );
    return TripSearchPageModel.fromJson(_jsonObject(response.data));
  }

  @override
  Future<TripSearchKeepAliveModel> keepAlive(
    String searchId, {
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.post(
      '${_searchPath(searchId)}/keep-alive',
      cancelToken: cancelToken,
    );
    return TripSearchKeepAliveModel.fromJson(_jsonObject(response.data));
  }

  String _searchPath(String searchId) =>
      '${ApiConstants.tripSearchEndpoint}/${Uri.encodeComponent(searchId)}';
}

Map<String, dynamic> _jsonObject(Object? data) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  throw const FormatException('Expected a JSON object response');
}
