import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class OpenMeteoService {
  static final OpenMeteoService _instance = OpenMeteoService._internal();
  factory OpenMeteoService() => _instance;
  OpenMeteoService._internal();

  Timer? _refreshTimer;
  final StreamController<double?> _temperatureController =
      StreamController<double?>.broadcast();

  Stream<double?> get temperatureStream => _temperatureController.stream;

  Future<Position?> _getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  Future<double?> fetchCurrentTemperature() async {
    final position = await _getCurrentPosition();
    if (position == null) return null;

    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=${position.latitude}'
      '&longitude=${position.longitude}'
      '&current_weather=true',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final temp = data['current_weather']['temperature'];
        return (temp as num).toDouble();
      }
    } catch (e) {
      print('Error fetching weather: $e');
    }
    return null;
  }

  void startAutoRefresh({Duration interval = const Duration(minutes: 10)}) {
    _refreshAndEmit();
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(interval, (_) => _refreshAndEmit());
  }

  Future<void> _refreshAndEmit() async {
    final temp = await fetchCurrentTemperature();
    _temperatureController.add(temp);
  }

  void stopAutoRefresh() {
    _refreshTimer?.cancel();
  }

  void dispose() {
    _refreshTimer?.cancel();
    _temperatureController.close();
  }
}
