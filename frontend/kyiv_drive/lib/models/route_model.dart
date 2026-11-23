import 'package:latlong2/latlong.dart';

class RouteModel {
  final String polyline;
  final int distanceMeters;
  final int durationSeconds;
  final List<LatLng> points;

  RouteModel({
    required this.polyline,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.points,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    final polyStr = json['polyline'] as String;
    return RouteModel(
      polyline: polyStr,
      distanceMeters: (json['distanceMeters'] as num).toInt(),
      durationSeconds: (json['durationSeconds'] as num).toInt(),
      points: _decodePolyline(polyStr),
    );
  }

  factory RouteModel.fromPolylineAndStats({
    required String polyline,
    required int distanceMeters,
    required int durationSeconds,
  }) {
    return RouteModel(
      polyline: polyline,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      points: _decodePolyline(polyline),
    );
  }

  static List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0; result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return poly;
  }
}