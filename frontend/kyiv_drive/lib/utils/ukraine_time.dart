import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

abstract final class UkraineTime {
  static final tz.Location _location = _initialize();

  static tz.Location _initialize() {
    tz_data.initializeTimeZones();
    return tz.getLocation('Europe/Kyiv');
  }

  static DateTime now([DateTime? instant]) =>
      tz.TZDateTime.from(instant ?? DateTime.now(), _location);

  static DateTime today([DateTime? instant]) {
    final local = now(instant);
    return DateTime(local.year, local.month, local.day);
  }

  /// Returns null for nonexistent wall-clock times and the later occurrence
  /// for autumn overlaps, matching the backend's Europe/Kyiv policy.
  static DateTime? departureInstant(DateTime date, int hour, int minute) {
    final wallClock = DateTime.utc(
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
    DateTime? latest;
    for (final offset in _location.zones.map((zone) => zone.offset).toSet()) {
      final candidate = wallClock.subtract(offset);
      final local = tz.TZDateTime.from(candidate, _location);
      if (local.year == date.year &&
          local.month == date.month &&
          local.day == date.day &&
          local.hour == hour &&
          local.minute == minute &&
          local.second == 0 &&
          local.millisecond == 0 &&
          (latest == null || candidate.isAfter(latest))) {
        latest = candidate;
      }
    }
    return latest;
  }
}
