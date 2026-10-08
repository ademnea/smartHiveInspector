/// Where the app finds the farmer API.
///
/// Override at build time without editing code, e.g. to test against a
/// local Laravel backend:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1/farmer
class ApiConfig {
  static const String _override = String.fromEnvironment('API_BASE_URL');

  // Deployed backend.
  static const String _production =
      'https://smarthive.iot-ra.net/api/v1/farmer';

  // Old API server, still used by screens not yet moved to the farmer API.
  // Disabled: those calls now go to the deployed backend instead.
  // static const String _legacyServer = 'http://196.43.168.57';

  /// Host for the old `/api/v1/...` endpoints. Currently the deployed backend.
  static String get legacyHost => Uri.parse(baseUrl).origin;

  static String get baseUrl =>
      _override.isNotEmpty ? _override : _production;
}
