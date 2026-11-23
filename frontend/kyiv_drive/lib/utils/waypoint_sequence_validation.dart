import 'package:latlong2/latlong.dart';

enum WaypointSequenceIssueType {
  firstMatchesOrigin,
  lastMatchesDestination,
  adjacentWaypointsMatch,
}

class WaypointSequenceIssue {
  final WaypointSequenceIssueType type;
  final int? firstWaypointNumber;
  final int? secondWaypointNumber;

  const WaypointSequenceIssue(
    this.type, {
    this.firstWaypointNumber,
    this.secondWaypointNumber,
  });
}

WaypointSequenceIssue? validateWaypointSequence({
  required LatLng origin,
  required LatLng destination,
  required List<LatLng> waypoints,
}) {
  if (waypoints.isEmpty) return null;

  if (_isSamePoint(waypoints.first, origin)) {
    return const WaypointSequenceIssue(
      WaypointSequenceIssueType.firstMatchesOrigin,
    );
  }

  if (_isSamePoint(waypoints.last, destination)) {
    return const WaypointSequenceIssue(
      WaypointSequenceIssueType.lastMatchesDestination,
    );
  }

  for (int index = 1; index < waypoints.length; index++) {
    if (_isSamePoint(waypoints[index - 1], waypoints[index])) {
      return WaypointSequenceIssue(
        WaypointSequenceIssueType.adjacentWaypointsMatch,
        firstWaypointNumber: index,
        secondWaypointNumber: index + 1,
      );
    }
  }

  return null;
}

bool _isSamePoint(LatLng first, LatLng second) {
  return first.latitude == second.latitude &&
      first.longitude == second.longitude;
}
