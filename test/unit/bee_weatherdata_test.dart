import 'package:HPGM/bee_counter/weatherdata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bee counter WeatherData parses JSON and applies optional defaults', () {
    final weather = WeatherData.fromJson({
      'timestamp': '2026-04-25T10:00:00.000',
      'temperature': 25,
      'humidity': 60,
      'wind_speed': 4,
    });

    expect(weather.timestamp, DateTime.parse('2026-04-25T10:00:00.000'));
    expect(weather.temperature, 25.0);
    expect(weather.humidity, 60.0);
    expect(weather.windSpeed, 4.0);
    expect(weather.rainfall, 0.0);
    expect(weather.solarRadiation, 0.0);
  });

  test('bee counter WeatherData serializes all weather fields', () {
    final timestamp = DateTime(2026, 4, 25, 10);
    final weather = WeatherData(
      timestamp: timestamp,
      temperature: 25.5,
      humidity: 61.0,
      windSpeed: 4.2,
      rainfall: 0.1,
      solarRadiation: 300,
    );

    final json = weather.toJson();

    expect(json['timestamp'], timestamp.toIso8601String());
    expect(json['temperature'], 25.5);
    expect(json['humidity'], 61.0);
    expect(json['wind_speed'], 4.2);
    expect(json['rainfall'], 0.1);
    expect(json['solar_radiation'], 300);
  });
}
