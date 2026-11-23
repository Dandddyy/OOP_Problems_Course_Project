import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../core/constants/map_bounds.dart';
import '../core/map/pin_map_layout.dart';
import '../widgets/map/route_map_warmup.dart';
import 'location_service.dart';
import 'map_configuration.dart';

class HomeMapStart {
  final LatLng? location;
  final bool requestPermissionOnHome;
  final RouteMapWarmup? tileWarmup;

  const HomeMapStart({
    this.location,
    this.requestPermissionOnHome = false,
    this.tileWarmup,
  });
}

abstract final class HomeMapStartup {
  static const tileWaitLimit = Duration(seconds: 1);
  static Future<HomeMapStart>? _pending;

  static void prepare() => _pending ??= locate();

  static Future<HomeMapStart> take() {
    final result = _pending ?? locate();
    _pending = null;
    return result;
  }

  static void discard() => _pending = null;

  static Future<HomeMapStart> warmAfterLogin(
    BuildContext context,
    HomeMapStart start,
  ) async {
    final configuration = MapConfiguration();
    RouteMapWarmup? warmup;
    try {
      warmup = RouteMapWarmupController().takeFor(
        context: context,
        options: PinMapLayout.home(location: start.location),
        visibleInsets: PinMapLayout.homeInsets(
          MediaQuery.viewPaddingOf(context).bottom,
        ),
        url: configuration.mapUrlTemplate,
        accessToken: configuration.mapAccessToken,
      );
      if (warmup == null) return start;

      // The visible map adopts pending requests if the time budget expires.
      await warmup.completed.timeout(tileWaitLimit, onTimeout: () {});
      return HomeMapStart(
        location: start.location,
        requestPermissionOnHome: start.requestPermissionOnHome,
        tileWarmup: warmup,
      );
    } catch (error) {
      warmup?.dispose();
      debugPrint('Home map warmup failed (${error.runtimeType})');
      return start;
    }
  }

  static Future<HomeMapStart> locate() async {
    try {
      final position = await LocationService.getStartupLocation();
      final point = LatLng(position.latitude, position.longitude);
      return HomeMapStart(
        location:
            position.latitude.isFinite &&
                position.longitude.isFinite &&
                KyivServiceArea.contains(point)
            ? point
            : null,
      );
    } on AppLocationDeniedException {
      return const HomeMapStart(requestPermissionOnHome: true);
    } catch (_) {
      // Location is an optional startup enhancement. Disabled services,
      // permanent denial, timeout and native failures all use the Kyiv view;
      // only an explicit GPS action should present these errors to the user.
      return const HomeMapStart();
    }
  }
}
