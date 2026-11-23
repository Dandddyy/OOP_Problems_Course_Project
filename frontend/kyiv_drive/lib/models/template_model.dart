import 'route_model.dart';
import 'address_model.dart';
import 'route_with_stops_model.dart';

class CreateTemplateRequestModel {
  final String requestId;
  final TemplateCreateRequestModel template;
  final List<TemplateStopCreateRequestModel> stops;

  const CreateTemplateRequestModel({
    required this.requestId,
    required this.template,
    required this.stops,
  });

  Map<String, dynamic> toJson() => {
    'requestId': requestId,
    'template': template.toJson(),
    'stops': stops.map((stop) => stop.toJson()).toList(),
  };
}

class TemplateCreateRequestModel {
  final String startShortAddress;
  final String startSubtitle;
  final String endShortAddress;
  final String endSubtitle;
  final double startLat;
  final double startLon;
  final double endLat;
  final double endLon;
  final String routePolyline;
  final int totalDurationSeconds;
  final int totalDistanceMeters;
  final List<TripWaypointModel> waypoints;

  const TemplateCreateRequestModel({
    required this.startShortAddress,
    required this.startSubtitle,
    required this.endShortAddress,
    required this.endSubtitle,
    required this.startLat,
    required this.startLon,
    required this.endLat,
    required this.endLon,
    required this.routePolyline,
    required this.totalDurationSeconds,
    required this.totalDistanceMeters,
    this.waypoints = const [],
  });

  Map<String, dynamic> toJson() => {
    'startShortAddress': startShortAddress,
    'startSubtitle': startSubtitle,
    'startLat': startLat,
    'startLon': startLon,
    'endShortAddress': endShortAddress,
    'endSubtitle': endSubtitle,
    'endLat': endLat,
    'endLon': endLon,
    'routePolyline': routePolyline,
    'totalDurationSeconds': totalDurationSeconds,
    'totalDistanceMeters': totalDistanceMeters,
    'waypoints': waypoints.map((waypoint) => waypoint.toJson()).toList(),
  };
}

class TemplateStopCreateRequestModel {
  final String stopId;
  final bool isEnabled;

  const TemplateStopCreateRequestModel({
    required this.stopId,
    required this.isEnabled,
  });

  Map<String, dynamic> toJson() => {'stopId': stopId, 'isEnabled': isEnabled};
}

class TemplateCreateResponseModel {
  final String templateId;
  final bool created;
  final String message;

  const TemplateCreateResponseModel({
    required this.templateId,
    required this.created,
    required this.message,
  });

  factory TemplateCreateResponseModel.fromJson(Map<String, dynamic> json) {
    final templateId = json['templateId'];
    final created = json['created'];
    if (templateId is! String || templateId.isEmpty || created is! bool) {
      throw const FormatException('Invalid template creation response');
    }

    return TemplateCreateResponseModel(
      templateId: templateId,
      created: created,
      message: TemplateMutationResponseModel.fromJson(json).message,
    );
  }
}

class TemplateMutationResponseModel {
  final String message;

  const TemplateMutationResponseModel({required this.message});

  factory TemplateMutationResponseModel.fromJson(Map<String, dynamic> json) {
    final message = json['message'];
    if (message is! String || message.isEmpty) {
      throw const FormatException(
        'Template response field "message" must be a non-empty string',
      );
    }
    return TemplateMutationResponseModel(message: message);
  }
}

class TemplateResponseModel {
  final TemplateModel template;
  final List<TemplateStopModel> stops;

  TemplateResponseModel({required this.template, required this.stops});

  factory TemplateResponseModel.fromJson(Map<String, dynamic> json) {
    return TemplateResponseModel(
      template: TemplateModel.fromJson(json['template']),
      stops:
          (json['stops'] as List?)
              ?.map((e) => TemplateStopModel.fromJson(e))
              .toList() ??
          [],
    );
  }

  RouteWithStopsModel toRouteWithStopsModel() {
    return RouteWithStopsModel(
      route: template.toRouteModel(),
      stops: stops
          .where((templateStop) => templateStop.isAvailable)
          .map(
            (templateStop) => StopOnRouteModel(
              stopId: templateStop.stopId,
              name: templateStop.name,
              lat: templateStop.lat,
              lon: templateStop.lon,
              etaSeconds: templateStop.cumulativeDurationSeconds,
              distanceMeters: templateStop.cumulativeDistanceMeters,
              isActive: templateStop.isEnabled,
            ),
          )
          .toList(),
    );
  }
}

class TemplateModel {
  final String id;
  final String userId;
  final String startShortAddress;
  final String startSubtitle;
  final String endShortAddress;
  final String endSubtitle;
  final double startLat;
  final double startLon;
  final double endLat;
  final double endLon;
  final String routePolyline;
  final int totalDurationSeconds;
  final int totalDistanceMeters;
  final bool isDriver;
  final DateTime createdAt;
  final List<TripWaypointModel> waypoints;

  TemplateModel({
    required this.id,
    required this.userId,
    required this.startShortAddress,
    required this.startSubtitle,
    required this.endShortAddress,
    required this.endSubtitle,
    required this.startLat,
    required this.startLon,
    required this.endLat,
    required this.endLon,
    required this.routePolyline,
    required this.totalDurationSeconds,
    required this.totalDistanceMeters,
    required this.isDriver,
    required this.createdAt,
    required this.waypoints,
  });

  factory TemplateModel.fromJson(Map<String, dynamic> json) {
    return TemplateModel(
      id: json['id'],
      userId: json['userId'],
      startShortAddress: json['startShortAddress'] ?? '',
      startSubtitle: json['startSubtitle'] ?? '',
      endShortAddress: json['endShortAddress'] ?? '',
      endSubtitle: json['endSubtitle'] ?? '',
      startLat: (json['startLat'] as num).toDouble(),
      startLon: (json['startLon'] as num).toDouble(),
      endLat: (json['endLat'] as num).toDouble(),
      endLon: (json['endLon'] as num).toDouble(),
      routePolyline: json['routePolyline'],
      totalDurationSeconds: (json['totalDurationSeconds'] as num).toInt(),
      totalDistanceMeters: (json['totalDistanceMeters'] as num).toInt(),
      isDriver: json['isDriver'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      waypoints:
          (json['waypoints'] as List?)
              ?.map((e) => TripWaypointModel.fromJson(e))
              .toList() ??
          [],
    );
  }

  RouteModel toRouteModel() {
    return RouteModel.fromPolylineAndStats(
      polyline: routePolyline,
      distanceMeters: totalDistanceMeters,
      durationSeconds: totalDurationSeconds,
    );
  }

  AddressModel get originAddress => AddressModel(
    shortAddress: startShortAddress,
    subtitle: startSubtitle,
    lat: startLat,
    lon: startLon,
  );

  AddressModel get destinationAddress => AddressModel(
    shortAddress: endShortAddress,
    subtitle: endSubtitle,
    lat: endLat,
    lon: endLon,
  );
}

class TemplateStopModel {
  final String id;
  final String stopId;
  final int sequenceNumber;
  final int cumulativeDurationSeconds;
  final int cumulativeDistanceMeters;
  final bool isEnabled;
  final bool isAvailable;
  final String? name;
  final double lat;
  final double lon;

  TemplateStopModel({
    required this.id,
    required this.stopId,
    required this.sequenceNumber,
    required this.cumulativeDurationSeconds,
    required this.cumulativeDistanceMeters,
    required this.isEnabled,
    required this.isAvailable,
    this.name,
    required this.lat,
    required this.lon,
  });

  factory TemplateStopModel.fromJson(Map<String, dynamic> json) {
    return TemplateStopModel(
      id: json['id'],
      stopId: json['stopId'],
      sequenceNumber: (json['sequenceNumber'] as num).toInt(),
      cumulativeDurationSeconds: (json['cumulativeDurationSeconds'] as num)
          .toInt(),
      cumulativeDistanceMeters: (json['cumulativeDistanceMeters'] as num)
          .toInt(),
      isEnabled: json['isEnabled'] ?? true,
      isAvailable: json['isAvailable'] == true,
      name: json['name'] as String?,
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
    );
  }
}

class TripWaypointModel {
  final double lat;
  final double lon;

  const TripWaypointModel({required this.lat, required this.lon});

  factory TripWaypointModel.fromJson(Map<String, dynamic> json) {
    return TripWaypointModel(
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {'lat': lat, 'lon': lon};
}
