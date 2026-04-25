import 'package:HPGM/apiary_overview_cards/build_overview_card.dart';
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
}
