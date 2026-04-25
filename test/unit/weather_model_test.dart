import 'package:HPGM/notifications/weather_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WeatherData.fromJson converts numeric fields to doubles', () {
    final weather = WeatherData.fromJson({
      'temperature': 24,
      'humidity': 61,
      'windSpeed': 4,
      'condition': 'Light rain',
      'timestamp': '2026-04-25T08:30:00.000',
    });

    expect(weather.temperature, 24.0);
    expect(weather.humidity, 61.0);
    expect(weather.windSpeed, 4.0);
    expect(weather.isRaining, isTrue);
    expect(weather.timestamp, DateTime.parse('2026-04-25T08:30:00.000'));
  });

  test('WeatherData.toJson emits stored values', () {
    final timestamp = DateTime(2026, 4, 25, 8, 30);
    final weather = WeatherData(
      temperature: 24.5,
      humidity: 61.2,
      windSpeed: 4.8,
      condition: 'Sunny',
      timestamp: timestamp,
    );

    final json = weather.toJson();

    expect(json['temperature'], 24.5);
    expect(json['humidity'], 61.2);
    expect(json['windSpeed'], 4.8);
    expect(json['condition'], 'Sunny');
    expect(json['timestamp'], timestamp.toIso8601String());
    expect(weather.isRaining, isFalse);
  });
}
