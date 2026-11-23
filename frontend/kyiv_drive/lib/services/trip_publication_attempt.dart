import 'dart:convert';

import '../models/trip_model.dart';
import '../utils/uuid.dart';

/// Keeps an unchanged publication retry on the same backend request ID.
class TripPublicationAttempt {
  String? _payload;
  CreateTripRequestModel? _request;

  bool matches({
    required TripCreateRequestModel trip,
    required List<TripStopCreateRequestModel> stops,
  }) => _payload == _encodePayload(trip, stops);

  CreateTripRequestModel prepare({
    required TripCreateRequestModel trip,
    required List<TripStopCreateRequestModel> stops,
  }) {
    final payload = _encodePayload(trip, stops);
    if (_payload != payload) {
      _request = CreateTripRequestModel(
        requestId: generateUuidV4(),
        trip: trip,
        stops: List.unmodifiable(stops),
      );
      _payload = payload;
    }
    return _request!;
  }

  String _encodePayload(
    TripCreateRequestModel trip,
    List<TripStopCreateRequestModel> stops,
  ) => jsonEncode({
    'trip': trip.toJson(),
    'stops': stops.map((stop) => stop.toJson()).toList(),
  });
}
