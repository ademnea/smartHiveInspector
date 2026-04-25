import 'dart:convert';

import 'package:HPGM/Services/weather_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  tearDown(() {
    WeatherService.resetHttpClientForTesting();
  });

  test('getCurrentWeather returns decoded response on success', () async {
    Uri? requestedUri;
    WeatherService.setHttpClientForTesting(
      MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode({
            'current': {'temp_c': 24},
          }),
          200,
        );
      }),
    );

    final result = await WeatherService.getCurrentWeather(location: 'Nairobi');

    expect(result['current']['temp_c'], 24);
    expect(requestedUri.toString(), contains('current.json'));
    expect(requestedUri.toString(), contains('q=Nairobi'));
  });

  test('getCurrentWeather returns error map on non-200 response', () async {
    WeatherService.setHttpClientForTesting(
      MockClient((request) async => http.Response('bad', 500)),
    );

    final result = await WeatherService.getCurrentWeather(location: 'Nairobi');

    expect(result['error'], contains('500'));
  });

  test('getWeatherForDate returns historical data for past dates', () async {
    WeatherService.setHttpClientForTesting(
      MockClient((request) async {
        expect(request.url.toString(), contains('history.json'));
        return http.Response(
          jsonEncode({
            'current': {'avgtemp_c': 22},
          }),
          200,
        );
      }),
    );

    final result = await WeatherService.getWeatherForDate(
      DateTime.now().subtract(const Duration(days: 2)),
      location: 'Nairobi',
    );

    expect(result['current']['avgtemp_c'], 22);
  });

  test('getWeatherSummary extracts normalized weather fields', () async {
    WeatherService.setHttpClientForTesting(
      MockClient((request) async {
        return http.Response(
          jsonEncode({
            'location': {'name': 'Nairobi'},
            'current': {
              'temp_c': 24.5,
              'humidity': 60,
              'wind_kph': 12,
              'precip_mm': 0.5,
              'uv': 7,
              'condition': {'text': 'Sunny'},
            },
          }),
          200,
        );
      }),
    );

    final summary = await WeatherService.getWeatherSummary(
      DateTime.now().subtract(const Duration(days: 2)),
      location: 'Nairobi',
    );

    expect(summary['temperature'], 24.5);
    expect(summary['humidity'], 60);
    expect(summary['windSpeed'], 12);
    expect(summary['precipitation'], 0.5);
    expect(summary['uvIndex'], 7);
    expect(summary['location']['name'], 'Nairobi');
  });

  test('getWeatherData returns the current dummy weather object', () async {
    final weather = await WeatherService().getWeatherData(-1.2, 36.8);

    expect(weather.temperature, 25.0);
    expect(weather.humidity, 60.0);
    expect(weather.condition, 'Sunny');
  });
}
