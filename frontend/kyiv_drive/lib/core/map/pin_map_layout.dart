import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../constants/app_ui_tokens.dart';
import '../constants/map_bounds.dart';
import 'pin_position_camera_constraint.dart';

/// The warmup and destination use exactly the same final camera, not a camera
/// which still needs an onMapReady jump to put the coordinate under the pin.
abstract final class PinMapLayout {
  static const kyiv = LatLng(50.4451, 30.5234);
  static const addressPinOffset = 83.0;
  static const homePinOffset = 115.0;
  static const homePanelHeight = 326.0;
  static final _homeConstraint = _constraint(homePinOffset);

  static MapOptions home({
    required LatLng? location,
    void Function(MapEvent)? onMapEvent,
  }) => _options(
    center: location == null ? kyiv : _centerUnderPin(location, homePinOffset),
    zoom: location == null ? 15 : 16,
    constraint: _homeConstraint,
    onMapEvent: onMapEvent,
  );

  static EdgeInsets homeInsets(double safeBottom) =>
      EdgeInsets.only(bottom: homePanelHeight + safeBottom);

  static MapOptions address({
    required LatLng location,
    VoidCallback? onMapReady,
    void Function(MapEvent)? onMapEvent,
  }) => point(
    location: location,
    pinOffset: addressPinOffset,
    onMapReady: onMapReady,
    onMapEvent: onMapEvent,
  );

  static MapOptions point({
    required LatLng location,
    required double pinOffset,
    VoidCallback? onMapReady,
    void Function(MapEvent)? onMapEvent,
  }) => _options(
    center: _centerUnderPin(location, pinOffset),
    zoom: 16,
    constraint: _constraint(pinOffset),
    onMapReady: onMapReady,
    onMapEvent: onMapEvent,
  );

  static LatLng _centerUnderPin(LatLng location, double pinOffset) {
    final camera = MapCamera.initialCamera(
      MapOptions(initialCenter: location, initialZoom: 16),
    );
    return camera.unprojectAtZoom(
      camera.projectAtZoom(location, 16) + Offset(0, pinOffset),
      16,
    );
  }

  static MapOptions waypoint({
    required List<LatLng> route,
    required double bottomExtent,
    LatLng? editingPoint,
    void Function(MapEvent)? onMapEvent,
  }) {
    final offset = bottomExtent / 2 + 3;
    if (editingPoint != null) {
      return point(
        location: editingPoint,
        pinOffset: offset,
        onMapEvent: onMapEvent,
      );
    }
    return _options(
      center: kyiv,
      zoom: 13,
      constraint: _constraint(offset),
      onMapEvent: onMapEvent,
      fit: CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(route),
        padding: EdgeInsets.only(
          top: 100,
          left: 40,
          right: 40,
          bottom: bottomExtent + AppDimens.pagePadding,
        ),
      ),
    );
  }

  static PinPositionCameraConstraint _constraint(double pinOffset) =>
      PinPositionCameraConstraint(
        bounds: KyivServiceArea.bounds,
        pinOffsetFromCenter: () => pinOffset,
      );

  static MapOptions _options({
    required LatLng center,
    required double zoom,
    required CameraConstraint constraint,
    CameraFit? fit,
    VoidCallback? onMapReady,
    void Function(MapEvent)? onMapEvent,
  }) => MapOptions(
    backgroundColor: AppColors.mapBackground,
    initialCenter: center,
    initialZoom: zoom,
    initialCameraFit: fit,
    minZoom: 11,
    maxZoom: 18,
    cameraConstraint: constraint,
    onMapReady: onMapReady,
    onMapEvent: onMapEvent,
    interactionOptions: const InteractionOptions(
      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
    ),
  );

  // A conservative opaque portion: don't omit visible tiles behind shadows,
  // rounded top corners, or the translucent waypoint action-bar gradient.
  static EdgeInsets addressInsets(double safeBottom) => EdgeInsets.only(
    bottom:
        safeBottom +
        AppDimens.bottomContentGap +
        AppDimens.buttonHeight +
        AppDimens.gapXl +
        AppDimens.controlHeight -
        AppDimens.gapSm,
  );
  static EdgeInsets waypointInsets(double safeBottom) => EdgeInsets.only(
    bottom: safeBottom + AppDimens.bottomContentGap + AppDimens.buttonHeight,
  );
}
