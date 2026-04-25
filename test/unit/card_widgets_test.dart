import 'package:HPGM/apiary_overview_cards/build_overview_card.dart';
import 'package:HPGM/components/custom_progress_bar.dart';
import 'package:HPGM/components/hive_card.dart' as hive_card;
import 'package:HPGM/components/pop_up.dart';
import 'package:HPGM/farm_card.dart';
import 'package:HPGM/farm_model.dart';
import 'package:HPGM/hive_model.dart' as hive_model;
import 'package:HPGM/notifications/hive_status_card.dart';
import 'package:HPGM/notifications/notification_card.dart';
import 'package:HPGM/notifications/notification_model.dart';
import 'package:HPGM/notifications/weather_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('buildOverviewCard renders title, value, and icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              buildOverviewCard('Total Hives', '12', Icons.hive, Colors.blue),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Total Hives'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.byIcon(Icons.hive), findsOneWidget);
  });

  testWidgets('buildFarmCard renders apiary details and action buttons', (tester) async {
    final farm = Farm(
      id: 1,
      ownerId: 2,
      name: 'North Apiary',
      district: 'Nairobi',
      average_temperature: 25,
      average_weight: 35,
      honeypercent: 70,
      address: 'Road 1',
      latitude: -1.2,
      longitude: 36.8,
      description: 'Test farm',
      createdAt: '2026-04-01',
      updatedAt: '2026-04-25',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: buildFarmCard(farm, context, 'token'),
          ),
        ),
      ),
    );

    expect(find.text('North Apiary'), findsOneWidget);
    expect(find.text('Nairobi, Road 1'), findsOneWidget);
    expect(find.text('Temperature'), findsOneWidget);
    expect(find.text('Honey Level'), findsOneWidget);
    expect(find.text('Manage'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('buildFarmCard delete action can be cancelled without deleting', (tester) async {
    var deleted = false;
    final farm = Farm(
      id: 1,
      ownerId: 2,
      name: 'North Apiary',
      district: 'Nairobi',
      average_temperature: 25,
      average_weight: 35,
      honeypercent: 70,
      address: 'Road 1',
      latitude: -1.2,
      longitude: 36.8,
      description: 'Test farm',
      createdAt: '2026-04-01',
      updatedAt: '2026-04-25',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: buildFarmCard(
              farm,
              context,
              'token',
              onDeleted: () async => deleted = true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Apiary North Apiary'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(deleted, isFalse);
  });

  testWidgets('HiveCard renders hive state and inspection action', (tester) async {
    final hive = hive_card.Hive(
      id: 5,
      longitude: '36.8',
      latitude: '-1.2',
      farmId: 1,
      createdAt: '2026-04-01',
      updatedAt: '2026-04-25',
      weight: 40,
      temperature: 26,
      honeyLevel: 65,
      isConnected: true,
      isColonized: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: hive_card.HiveCard(
            hive: hive,
            token: 'token',
            apiaryLocation: 'Nairobi',
            farmName: 'North Apiary',
          ),
        ),
      ),
    );

    expect(find.text('Hive 5'), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Colonized'), findsOneWidget);
    expect(find.text('Inspect Hive'), findsOneWidget);
  });

  testWidgets('HiveStatusCard renders hive and weather readings', (tester) async {
    final hive = hive_model.Hive.fromJson({
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
          body: HiveStatusCard(
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
    );

    expect(find.text('Hive 6'), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Colonized'), findsOneWidget);
    expect(find.text('Interior Temperature'), findsOneWidget);
    expect(find.text('Weather Conditions'), findsOneWidget);
    expect(find.text('Sunny'), findsOneWidget);
  });

  testWidgets('NotificationCard renders severity and expected action buttons', (tester) async {
    var tapped = false;
    final notification = HiveNotification(
      id: 'n1',
      title: 'Connection lost',
      message: 'Hive device is offline',
      timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
      type: NotificationType.connection,
      severity: NotificationSeverity.high,
      hiveId: 4,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationCard(
            notification: notification,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Connection lost'), findsOneWidget);
    expect(find.text('Hive device is offline'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
    expect(find.text('Troubleshoot'), findsOneWidget);
    expect(find.text('Check Device'), findsOneWidget);

    await tester.tap(find.byType(NotificationCard));
    expect(tapped, isTrue);
  });

  test('CustomProgressBar maps temperature values to progress and colors', () {
    const bar = CustomProgressBar(value: 26);

    expect(bar.getValue(10), 0.15);
    expect(bar.getValue(26), 0.64);
    expect(bar.getValue(32), 0.74);
    expect(bar.getValue(40), 0.85);
    expect(bar.getFillColor(26), Colors.green);
    expect(const CustomProgressBar(value: 35).getFillColor(35), Colors.red);
  });

  test('popup message helpers return expected threshold messages', () {
    expect(determineMessage(null), 'No data available');
    expect(determineMessage(10), contains('Low'));
    expect(determineMessage(25), contains('Moderate'));
    expect(determineMessage(35), contains('High'));

    expect(determineHoneyMessage(null), 'No data available');
    expect(determineHoneyMessage(10), contains('Low'));
    expect(determineHoneyMessage(35), contains('Moderate'));
    expect(determineHoneyMessage(80), contains('High'));
  });
}
