import 'package:HPGM/components/hive_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('HiveCard renders hive state and inspection action', (tester) async {
    final hive = Hive(
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
          body: HiveCard(
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
}
