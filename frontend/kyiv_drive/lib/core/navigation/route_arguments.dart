import 'package:latlong2/latlong.dart';

import '../../models/address_model.dart';
import '../../models/route_model.dart';
import '../../models/route_with_stops_model.dart';
import '../../models/trip_search_model.dart';
import '../../widgets/map/route_map_warmup.dart';

abstract class RideRouteArgs {
  final bool isRegularRide;
  final DateTime selectedDateTime;
  final String selectedTime;
  final List<bool> selectedDays;

  RideRouteArgs({
    required this.isRegularRide,
    required this.selectedDateTime,
    required this.selectedTime,
    required List<bool> selectedDays,
  }) : selectedDays = List<bool>.unmodifiable(selectedDays) {
    if (selectedDays.length != 7) {
      throw ArgumentError.value(
        selectedDays,
        'selectedDays',
        'Ride planning requires exactly seven weekday values',
      );
    }
  }
}

final class GoogleRegistrationRouteArgs {
  final String googleEmail;
  final String googleName;
  final String? googlePhotoUrl;
  final String idToken;

  const GoogleRegistrationRouteArgs({
    required this.googleEmail,
    required this.googleName,
    this.googlePhotoUrl,
    required this.idToken,
  });
}

final class SavedTemplatesRouteArgs extends RideRouteArgs {
  SavedTemplatesRouteArgs({
    required super.isRegularRide,
    required super.selectedDateTime,
    required super.selectedTime,
    required super.selectedDays,
  });
}

final class AddressSearchRouteArgs extends RideRouteArgs {
  final AddressModel? initialOrigin;
  final AddressModel? initialDestination;
  final bool focusOnDestination;

  AddressSearchRouteArgs({
    this.initialOrigin,
    this.initialDestination,
    this.focusOnDestination = true,
    required super.isRegularRide,
    required super.selectedDateTime,
    required super.selectedTime,
    required super.selectedDays,
  });
}

final class MapSelectionRouteArgs extends RideRouteArgs {
  final LatLng? initialLocation;
  final Future<LatLng?>? userLocation;
  final RouteMapWarmup? tileWarmup;
  final AddressModel? knownOrigin;
  final AddressModel? knownDestination;
  final bool isSelectingDestination;

  MapSelectionRouteArgs({
    this.initialLocation,
    this.userLocation,
    this.tileWarmup,
    this.knownOrigin,
    this.knownDestination,
    this.isSelectingDestination = true,
    required super.isRegularRide,
    required super.selectedDateTime,
    required super.selectedTime,
    required super.selectedDays,
  });
}

final class DriverRoutePreviewArgs extends RideRouteArgs {
  final AddressModel origin;
  final AddressModel destination;
  final bool isFromSavedTemplates;
  final RouteWithStopsModel? preloadedRouteWithStops;
  final List<LatLng>? waypoints;

  DriverRoutePreviewArgs({
    required this.origin,
    required this.destination,
    required super.isRegularRide,
    required super.selectedDateTime,
    required super.selectedTime,
    required super.selectedDays,
    this.isFromSavedTemplates = false,
    this.preloadedRouteWithStops,
    List<LatLng>? waypoints,
  }) : waypoints = waypoints == null
           ? null
           : List<LatLng>.unmodifiable(waypoints);
}

final class PassengerRoutePreviewArgs extends RideRouteArgs {
  final AddressModel origin;
  final AddressModel destination;
  final bool isFromSavedTemplates;
  final RouteModel? preloadedRoute;

  PassengerRoutePreviewArgs({
    required this.origin,
    required this.destination,
    required super.isRegularRide,
    required super.selectedDateTime,
    required super.selectedTime,
    required super.selectedDays,
    this.isFromSavedTemplates = false,
    this.preloadedRoute,
  });
}

final class TripSearchResultsRouteArgs {
  final TripSearchRequestModel request;

  const TripSearchResultsRouteArgs({required this.request});
}
