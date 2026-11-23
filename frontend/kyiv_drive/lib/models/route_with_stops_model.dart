import 'route_model.dart';

class RouteWithStopsModel {
  final RouteModel route;
  final List<StopOnRouteModel> stops;

  RouteWithStopsModel({
    required this.route,
    required this.stops,
  });

  factory RouteWithStopsModel.fromJson(Map<String, dynamic> json) {
    return RouteWithStopsModel(
      route: RouteModel.fromJson(json['route']),
      stops: (json['stops'] as List<dynamic>?)
          ?.map((e) => StopOnRouteModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
    );
  }
}

class StopOnRouteModel {
  final String stopId;
  final String? name;
  final double lat;
  final double lon;
  final int etaSeconds;
  final int distanceMeters;
  bool isActive;

  StopOnRouteModel({
    required this.stopId,
    this.name,
    required this.lat,
    required this.lon,
    required this.etaSeconds,
    required this.distanceMeters,
    this.isActive = true,
  });

  factory StopOnRouteModel.fromJson(Map<String, dynamic> json) {
    return StopOnRouteModel(
      stopId: json['stopId'] as String,
      name: json['name'] as String?,
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      etaSeconds: (json['etaSeconds'] as num).toInt(),
      distanceMeters: (json['distanceMeters'] as num).toInt(),
      isActive: json['isActive'] ?? true,
    );
  }
}