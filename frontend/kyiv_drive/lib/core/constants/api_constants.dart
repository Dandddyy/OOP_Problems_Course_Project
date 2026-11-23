import 'dart:io';

class ApiConstants {
  ApiConstants._();

  static const String _baseAndroidUrl = "http://10.0.2.2:2525";
  static const String _baseIosUrl = "http://localhost:2525";

  static String get baseUrl {
    return Platform.isAndroid ? _baseAndroidUrl : _baseIosUrl;
  }

  static const String loginEndpoint = "/api/user/login";
  static const String refreshEndpoint = "/api/user/refresh";
  static const String logoutEndpoint = "/api/user/logout";
  static const String logoutOthersEndpoint = "/api/user/logout-others";
  static const String sessionsEndpoint = "/api/user/sessions";
  static const String currentUserEndpoint = "/api/user/me";
  static const String sendRegistrationCodeEndpoint =
      '/api/user/send-registration-code';
  static const String registerEndpoint = "/api/user/register";
  static const String googleLoginEndpoint = "/api/user/google/login";
  static const String googleRegisterEndpoint = "/api/user/google/register";
  static const String sendCodeEndpoint = "/api/user/send-code";
  static const String verifyCodeEndpoint = "/api/user/verify-code";
  static const String resetPasswordEndpoint = "/api/user/reset-password";
  static const String configMapEndpoint = "/api/config/map";
  static const String reverseGeocodeEndpoint = "/api/map/reverse-geocode";
  static const String autocompleteEndpoint = "/api/map/autocomplete";
  static const String getRouteEndpoint = "/api/map/route";
  static const String getRouteWithStopsEndpoint = "/api/map/route-with-stops";
  static const String templateEndpoint = "/api/template";
  static const String tripEndpoint = "/api/trip";
  static const String tripSearchEndpoint = '/api/trip/search';
  static const String switchModeEndpoint = "/api/user/switch-mode";
  static const String carsEndpoint = '/api/car';
  static const String getModelsEndpoint = '/api/car/models';
  static const String initCarsEndpoint = '/api/car/init';
  static const String userRatingEndpoint = "/api/user/profile-summary";
}
