import 'dart:ui';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class PinPositionCameraConstraint extends CameraConstraint {
  static const double _edgeInset = 0.0000001;

  final LatLngBounds bounds;
  final double Function() pinOffsetFromCenter;

  const PinPositionCameraConstraint({
    required this.bounds,
    required this.pinOffsetFromCenter,
  });

  @override
  MapCamera constrain(MapCamera camera) {
    if (camera.nonRotatedSize == MapCamera.kImpossibleSize) {
      return camera;
    }

    final screenCenter = camera.nonRotatedSize.center(Offset.zero);
    final pinScreenPosition = Offset(
      screenCenter.dx,
      screenCenter.dy - pinOffsetFromCenter(),
    );
    final pinPosition = camera.screenOffsetToLatLng(pinScreenPosition);

    final constrainedPinPosition = LatLng(
      _clampInside(pinPosition.latitude, bounds.south, bounds.north),
      _clampInside(pinPosition.longitude, bounds.west, bounds.east),
    );

    if (constrainedPinPosition == pinPosition) {
      return camera;
    }

    final pinDistanceFromCenter = screenCenter - pinScreenPosition;
    final constrainedPinPoint = camera.projectAtZoom(
      constrainedPinPosition,
      camera.zoom,
    );
    final constrainedCenter = camera.unprojectAtZoom(
      constrainedPinPoint + pinDistanceFromCenter,
      camera.zoom,
    );

    return camera.withPosition(center: constrainedCenter);
  }

  double _clampInside(double value, double minimum, double maximum) {
    if (value < minimum) {
      return (minimum + _edgeInset).clamp(minimum, maximum).toDouble();
    }
    if (value > maximum) {
      return (maximum - _edgeInset).clamp(minimum, maximum).toDouble();
    }
    return value;
  }
}
