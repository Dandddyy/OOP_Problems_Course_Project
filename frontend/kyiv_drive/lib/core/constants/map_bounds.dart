import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:latlong2/latlong.dart';

abstract final class KyivServiceArea {
  static const double minLatitude = 50.08;
  static const double maxLatitude = 50.75;
  static const double minLongitude = 30.08;
  static const double maxLongitude = 31.02;

  static final LatLngBounds bounds = LatLngBounds(
    const LatLng(minLatitude, minLongitude),
    const LatLng(maxLatitude, maxLongitude),
  );

  static bool contains(LatLng point) {
    return bounds.contains(point);
  }
}
