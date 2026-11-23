class AddressModel {
  final String? shortAddress;
  final String? subtitle;
  final double lat;
  final double lon;

  AddressModel({
    required this.shortAddress,
    this.subtitle,
    required this.lat,
    required this.lon,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      shortAddress: json['shortAddress'],
      subtitle: json['subtitle'],
      lat: (json['lat'] ?? 0).toDouble(),
      lon: (json['lon'] ?? 0).toDouble(),
    );
  }

  String get fullAddress {
    if (shortAddress == null || shortAddress!.isEmpty) return "";
    return subtitle != null && subtitle!.isNotEmpty
        ? "$shortAddress, $subtitle"
        : shortAddress!;
  }
}