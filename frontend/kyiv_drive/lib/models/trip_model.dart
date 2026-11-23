import 'template_model.dart' show TripWaypointModel;

enum TripScheduleType {
  oneTime('ONE_TIME'),
  recurring('RECURRING');

  final String apiValue;

  const TripScheduleType(this.apiValue);
}

enum TripPricingType {
  fixed('FIXED'),
  perKilometer('PER_KM');

  final String apiValue;

  const TripPricingType(this.apiValue);
}

class CreateTripRequestModel {
  final String requestId;
  final TripCreateRequestModel trip;
  final List<TripStopCreateRequestModel> stops;

  const CreateTripRequestModel({
    required this.requestId,
    required this.trip,
    this.stops = const [],
  });

  Map<String, dynamic> toJson() => {
    'requestId': requestId,
    'trip': trip.toJson(),
    'stops': stops.map((stop) => stop.toJson()).toList(),
  };
}

class TripCreateRequestModel {
  final String carId;
  final String startShortAddress;
  final String? startSubtitle;
  final String endShortAddress;
  final String? endSubtitle;
  final double startLat;
  final double startLon;
  final double endLat;
  final double endLon;
  final List<TripWaypointModel> waypoints;
  final String routePolyline;
  final int totalDistanceMeters;
  final int totalDurationSeconds;
  final TripScheduleType scheduleType;

  /// Calendar date in Ukraine; serialized without converting it to UTC.
  final DateTime firstDepartureDate;

  /// Local departure time in Ukraine, in HH:mm format.
  final String departureLocalTime;

  final bool monday;
  final bool tuesday;
  final bool wednesday;
  final bool thursday;
  final bool friday;
  final bool saturday;
  final bool sunday;
  final TripPricingType pricingType;
  final num priceAmount;
  final bool negotiationAllowed;
  final String? description;

  const TripCreateRequestModel({
    required this.carId,
    required this.startShortAddress,
    this.startSubtitle,
    required this.endShortAddress,
    this.endSubtitle,
    required this.startLat,
    required this.startLon,
    required this.endLat,
    required this.endLon,
    this.waypoints = const [],
    required this.routePolyline,
    required this.totalDistanceMeters,
    required this.totalDurationSeconds,
    required this.scheduleType,
    required this.firstDepartureDate,
    required this.departureLocalTime,
    this.monday = false,
    this.tuesday = false,
    this.wednesday = false,
    this.thursday = false,
    this.friday = false,
    this.saturday = false,
    this.sunday = false,
    required this.pricingType,
    required this.priceAmount,
    this.negotiationAllowed = true,
    this.description,
  });

  Map<String, dynamic> toJson() => {
    'carId': carId,
    'startShortAddress': startShortAddress,
    'startSubtitle': startSubtitle,
    'endShortAddress': endShortAddress,
    'endSubtitle': endSubtitle,
    'startLat': startLat,
    'startLon': startLon,
    'endLat': endLat,
    'endLon': endLon,
    'waypoints': waypoints.map((waypoint) => waypoint.toJson()).toList(),
    'routePolyline': routePolyline,
    'totalDistanceMeters': totalDistanceMeters,
    'totalDurationSeconds': totalDurationSeconds,
    'scheduleType': scheduleType.apiValue,
    'firstDepartureDate': _calendarDate(firstDepartureDate),
    'departureLocalTime': departureLocalTime,
    'monday': monday,
    'tuesday': tuesday,
    'wednesday': wednesday,
    'thursday': thursday,
    'friday': friday,
    'saturday': saturday,
    'sunday': sunday,
    'pricingType': pricingType.apiValue,
    'priceAmount': priceAmount,
    'negotiationAllowed': negotiationAllowed,
    'description': description,
  };
}

class TripStopCreateRequestModel {
  final String stopId;
  final bool isEnabled;

  const TripStopCreateRequestModel({
    required this.stopId,
    this.isEnabled = true,
  });

  Map<String, dynamic> toJson() => {'stopId': stopId, 'isEnabled': isEnabled};
}

class TripCreateResponseModel {
  final String tripId;
  final bool created;
  final DateTime? confirmationExpiresAt;
  final String message;

  const TripCreateResponseModel({
    required this.tripId,
    required this.created,
    required this.confirmationExpiresAt,
    required this.message,
  });

  factory TripCreateResponseModel.fromJson(Map<String, dynamic> json) {
    final created = json['created'];
    if (created is! bool) {
      throw const FormatException(
        'Trip response field "created" must be a boolean',
      );
    }
    final expiresAt = json['confirmationExpiresAt'];
    DateTime? confirmationExpiresAt;
    if (expiresAt != null) {
      if (expiresAt is! String) {
        throw const FormatException(
          'Trip confirmation expiry must be an ISO-8601 instant',
        );
      }
      confirmationExpiresAt = DateTime.tryParse(expiresAt);
      if (confirmationExpiresAt == null || !confirmationExpiresAt.isUtc) {
        throw const FormatException(
          'Trip confirmation expiry must include a valid time zone',
        );
      }
    }
    return TripCreateResponseModel(
      tripId: _requiredString(json, 'tripId'),
      created: created,
      confirmationExpiresAt: confirmationExpiresAt,
      message: _requiredString(json, 'message'),
    );
  }
}

String _calendarDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _requiredString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException(
    'Trip response field "$field" must be a non-empty string',
  );
}
