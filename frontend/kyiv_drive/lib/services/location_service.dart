import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class AppLocationDisabledException implements Exception {}

class AppLocationDeniedException implements Exception {}

class AppLocationPermanentException implements Exception {}

class LocationService {
  static Future<Position> getCurrentLocation({
    bool requestPermission = true,
  }) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw AppLocationDisabledException();
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      if (!requestPermission) {
        throw AppLocationDeniedException();
      }

      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        throw AppLocationDeniedException();
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw AppLocationPermanentException();
    }

    return _getPosition(true, const Duration(seconds: 10));
  }

  /// Includes service/permission checks in the budget and never asks the user
  /// to enable permissions or change location settings during map preparation.
  static Future<Position> getStartupLocation({
    Duration timeLimit = const Duration(milliseconds: 1500),
  }) {
    final elapsed = Stopwatch()..start();
    var expired = false;
    Duration remaining() {
      final value = timeLimit - elapsed.elapsed;
      if (expired || value <= Duration.zero) {
        throw TimeoutException('Startup location');
      }
      return value;
    }

    Future<Position> locate() async {
      final enabled = await Geolocator.isLocationServiceEnabled();
      remaining();
      if (!enabled) throw AppLocationDisabledException();
      final permission = await Geolocator.checkPermission();
      final positionBudget = remaining();
      if (permission == LocationPermission.deniedForever) {
        throw AppLocationPermanentException();
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        throw AppLocationDeniedException();
      }
      return _getPosition(false, positionBudget);
    }

    return locate().timeout(
      timeLimit,
      onTimeout: () {
        expired = true;
        throw TimeoutException('Startup location');
      },
    );
  }

  static Future<Position> _getPosition(
    bool allowSystemDialogs,
    Duration timeLimit,
  ) => Geolocator.getCurrentPosition(
    locationSettings: defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            // FusedLocationProvider may launch a settings-resolution dialog
            // even with permission already granted. LocationManager does not.
            forceLocationManager: !allowSystemDialogs,
            accuracy: LocationAccuracy.high,
            timeLimit: timeLimit,
          )
        : LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: timeLimit,
          ),
  );

  static Future<bool> openAppPermissionSettings() {
    return Geolocator.openAppSettings();
  }

  static Future<bool> openSystemLocationSettings() {
    return Geolocator.openLocationSettings();
  }
}
