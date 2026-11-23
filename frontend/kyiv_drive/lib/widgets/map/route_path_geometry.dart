import 'dart:ui' as ui;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Cached local coordinates shared by route drawing, highlights and markers.
class RoutePathGeometry {
  static const referenceZoom = 16.0;

  final LatLng origin;
  final ui.PathMetric metric;
  final Crs _crs;
  final ui.Offset _projectedOrigin;
  final List<ui.Offset> _offsets;
  final List<double> _distances;
  final _fractions = <(LatLng, double?), double>{};

  RoutePathGeometry._(
    this.origin,
    this.metric,
    this._crs,
    this._projectedOrigin,
    this._offsets,
    this._distances,
  );

  static RoutePathGeometry? fromPoints(List<LatLng> points, Crs crs) {
    if (points.length < 2) return null;
    final origin = crs.latLngToOffset(points.first, referenceZoom);
    if (!origin.dx.isFinite || !origin.dy.isFinite) return null;
    final path = ui.Path()..moveTo(0, 0);
    final offsets = <ui.Offset>[ui.Offset.zero];
    final distances = <double>[0];
    for (final point in points.skip(1)) {
      final offset = crs.latLngToOffset(point, referenceZoom) - origin;
      if (!offset.dx.isFinite || !offset.dy.isFinite) return null;
      distances.add(distances.last + (offset - offsets.last).distance);
      offsets.add(offset);
      path.lineTo(offset.dx, offset.dy);
    }
    final metrics = path.computeMetrics().iterator;
    if (!metrics.moveNext() || metrics.current.length <= 0) return null;
    return RoutePathGeometry._(
      points.first,
      metrics.current,
      crs,
      origin,
      offsets,
      distances,
    );
  }

  /// Locate a marker on the actual drawn line, rather than its bounding box.
  /// The server's distance fraction disambiguates repeated/crossing segments.
  double fractionAt(LatLng point, {double? fractionHint}) =>
      _fractions.putIfAbsent((
        point,
        fractionHint,
      ), () => _fractionAt(point, fractionHint));

  double _fractionAt(LatLng point, double? fractionHint) {
    final offset = _crs.latLngToOffset(point, referenceZoom) - _projectedOrigin;
    var nearestSquared = double.infinity;
    var nearestFraction = 0.0;
    for (var i = 1; i < _offsets.length; i++) {
      final segment = _offsets[i] - _offsets[i - 1];
      final squaredLength = segment.distanceSquared;
      if (squaredLength == 0) continue;
      final relative = offset - _offsets[i - 1];
      final t =
          ((relative.dx * segment.dx + relative.dy * segment.dy) /
                  squaredLength)
              .clamp(0.0, 1.0);
      final squared =
          (offset - (_offsets[i - 1] + segment * t)).distanceSquared;
      final fraction =
          (_distances[i - 1] + (_distances[i] - _distances[i - 1]) * t) /
          _distances.last;
      final tied = (squared - nearestSquared).abs() < 0.000001;
      if (squared < nearestSquared && !tied ||
          tied &&
              fractionHint != null &&
              (fraction - fractionHint).abs() <
                  (nearestFraction - fractionHint).abs()) {
        nearestSquared = squared;
        nearestFraction = fraction;
      }
    }
    return nearestFraction.clamp(0.0, 1.0);
  }
}
