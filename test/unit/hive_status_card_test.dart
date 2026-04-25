import 'package:HPGM/hive_model.dart';
import 'package:HPGM/notifications/hive_status_card.dart';
import 'package:HPGM/notifications/weather_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('HiveStatusCard renders hive and weather readings', (tester) async {
    final hive = Hive.fromJson({
      'id': 6,
      'longitude': '36.8',
      'latitude': '-1.2',
      'farm_id': 1,
      'state': {
        'weight': {
          'record': 20,
          'honey_percentage': 50,
          'date_collected': '2026-04-25T08:00:00',
        },
        'temperature': {
          'interior_temperature': 28,
          'exterior_temperature': 24,
          'date_collected': '2026-04-25T08:00:00',
        },
        'humidity': {
          'interior_humidity': 60,
          'exterior_humidity': 65,
          'date_collected': '2026-04-25T08:00:00',
        },
        'carbon_dioxide': {
          'record': 450,
          'date_collected': '2026-04-25T08:00:00',
        },
        'connection_status': {'Connected': true},
        'colonization_status': {'Colonized': true},
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HiveStatusCard(
              hive: hive,
              weatherData: WeatherData(
                temperature: 24,
                humidity: 60,
                windSpeed: 8,
                condition: 'Sunny',
                timestamp: DateTime(2026, 4, 25),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Hive 6'), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Colonized'), findsOneWidget);
    expect(find.text('Interior Temperature'), findsOneWidget);
    expect(find.text('Weather Conditions'), findsOneWidget);
    expect(find.text('Sunny'), findsOneWidget);
  });
}
