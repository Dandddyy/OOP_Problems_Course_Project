/// Version ordering used by the backend's ClientVersionPolicy.
final class AppVersion implements Comparable<AppVersion> {
  static final _pattern = RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?$');

  final List<BigInt> _parts;

  AppVersion._(this._parts);

  static AppVersion? tryParse(String version) {
    final match = _pattern.firstMatch(version.trim());
    if (match == null) return null;

    return AppVersion._([
      BigInt.parse(match[1]!),
      BigInt.parse(match[2]!),
      BigInt.parse(match[3]!),
      BigInt.parse(match[4] ?? '0'),
    ]);
  }

  @override
  int compareTo(AppVersion other) {
    for (var i = 0; i < _parts.length; i++) {
      final order = _parts[i].compareTo(other._parts[i]);
      if (order != 0) return order;
    }
    return 0;
  }
}
