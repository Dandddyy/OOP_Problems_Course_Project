import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import 'map_config_service.dart';

class MapConfiguration extends ChangeNotifier {
  static final MapConfiguration _instance = MapConfiguration._internal();
  factory MapConfiguration() => _instance;
  MapConfiguration._internal();

  String? mapUrlTemplate;
  String? mapAccessToken;

  bool get isReady => mapUrlTemplate != null && mapAccessToken != null;

  Future<void> fetchConfig() async {
    try {
      final service = MapConfigService(ApiClient().dio);
      final config = await service.fetchConfig();
      mapUrlTemplate = config["urlTemplate"];
      mapAccessToken = config["accessToken"];
      notifyListeners();
    } catch (e) {
      print("MapConfiguration: Failed to fetch map config - $e");
    }
  }

  void clear() {
    mapUrlTemplate = null;
    mapAccessToken = null;
    notifyListeners();
  }
}