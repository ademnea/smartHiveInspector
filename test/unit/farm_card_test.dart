import 'package:HPGM/farm_card.dart';
import 'package:HPGM/farm_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Farm _farm() {
  return Farm(
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
}

void main() {
  testWidgets('buildFarmCard renders apiary details and action buttons', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: buildFarmCard(_farm(), context, 'token'),
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

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: buildFarmCard(
              _farm(),
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
}
