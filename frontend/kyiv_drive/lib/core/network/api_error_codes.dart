import 'package:dio/dio.dart';

abstract final class ApiErrorCodes {
  static const String appUpdateRequired = 'app_update_required';
  static const String operationBusy = 'operation_busy';
  static const String routeSnapshotChanged = 'route_snapshot_changed';
  static const String requestIdConflict = 'request_id_conflict';
  static const String tripDriverRequired = 'trip_driver_required';
  static const String tripCarUnavailable = 'trip_car_unavailable';
  static const String tripActiveLimitReached = 'trip_active_limit_reached';
  static const String tripDuplicate = 'trip_duplicate';
  static const String tripPriceInvalid = 'trip_price_invalid';
  static const String tripDepartureDateInvalid = 'trip_departure_date_invalid';
  static const String tripDepartureTimeInvalid = 'trip_departure_time_invalid';
  static const String tripDepartureInPast = 'trip_departure_in_past';
  static const String tripOneTimeDaysInvalid = 'trip_one_time_days_invalid';
  static const String tripRecurringDaysInvalid = 'trip_recurring_days_invalid';
  static const String tripSearchInvalidRequest = 'trip_search_invalid_request';
  static const String tripSearchInvalidCursor = 'trip_search_invalid_cursor';
  static const String tripSearchExpired = 'trip_search_expired';
  static const String tripSearchChanged = 'trip_search_changed';
  static const String tripSearchGraphChanged = 'trip_search_graph_changed';
  static const String tripSearchBusy = 'trip_search_busy';
  static const String tripSearchRateLimited = 'trip_search_rate_limited';
  static const String tripSearchVariantExpired = 'trip_search_variant_expired';
  static const String tripSearchNewSearchRequired =
      'trip_search_new_search_required';
  static const String tripSearchTooBroad = 'trip_search_too_broad';
  static const String tripSearchRoutingUnavailable =
      'trip_search_routing_unavailable';
  static const String tripSearchCacheUnavailable =
      'trip_search_cache_unavailable';
}

bool isServiceBusyError(Object error) {
  final data = error is DioException ? error.response?.data : null;
  return data is Map &&
      (data['code'] == ApiErrorCodes.operationBusy ||
          data['code'] == ApiErrorCodes.tripSearchBusy);
}

bool isRouteSnapshotChangedError(Object error) {
  if (error is! DioException || error.response?.statusCode != 409) {
    return false;
  }

  final data = error.response?.data;
  return data is Map && data['code'] == ApiErrorCodes.routeSnapshotChanged;
}

bool isAppUpdateRequiredError(DioException error) {
  if (error.response?.statusCode != 426) {
    return false;
  }

  final data = error.response?.data;
  return data is Map && data['code'] == ApiErrorCodes.appUpdateRequired;
}
