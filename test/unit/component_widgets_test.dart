import 'package:HPGM/components/custom_text_field.dart';
import 'package:HPGM/components/hive_tips.dart';
import 'package:HPGM/components/honey_sheet.dart' as honey_sheet;
import 'package:HPGM/components/individual_bar.dart';
import 'package:HPGM/components/notificationbar.dart';
import 'package:HPGM/components/temperature_sheet.dart' as temp_sheet;
import 'package:HPGM/tab_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CustomTextField renders hint, prefix icon, suffix icon, and accepts input', (
    tester,
  ) async {
    final controller = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomTextField(
            controller: controller,
            hintText: 'Email',
            icon: Icons.email,
            suffixIcon: const Icon(Icons.check),
          ),
        ),
      ),
    );

    expect(find.text('Email'), findsOneWidget);
    expect(find.byIcon(Icons.email), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'keeper@example.com');
    expect(controller.text, 'keeper@example.com');
  });

  testWidgets('HiveTips renders title and content', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HiveTips(
            title: 'Inspect weekly',
            content: 'Check hive weight and honey levels every week.',
          ),
        ),
      ),
    );

    expect(find.text('Inspect weekly'), findsOneWidget);
    expect(find.text('Check hive weight and honey levels every week.'), findsOneWidget);
  });

  testWidgets('NotificationComponent renders date, title, and content', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NotificationComponent(
            date: '2026-04-25',
            title: 'Hive alert',
            content: 'Temperature is above the safe range.',
          ),
        ),
      ),
    );

    expect(find.text('2026-04-25'), findsOneWidget);
    expect(find.text('Hive alert'), findsOneWidget);
    expect(find.text('Temperature is above the safe range.'), findsOneWidget);
  });

  testWidgets('basic honey and temperature sheets render titles and values', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              honey_sheet.buildHoneySheet('Honey', 72.5),
              temp_sheet.buildTempSheet('Temperature', 28.0),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Honey'), findsOneWidget);
    expect(find.text('72.5%'), findsOneWidget);
    expect(find.text('Temperature'), findsOneWidget);
    expect(find.textContaining('28.0'), findsOneWidget);
  });

  testWidgets('TabItem hides zero count and caps high counts at 9+', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DefaultTabController(
          length: 2,
          child: Scaffold(
            body: TabBar(
              tabs: [
                TabItem(title: 'Unread', count: 0),
                TabItem(title: 'Alerts', count: 12),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Unread'), findsOneWidget);
    expect(find.text('Alerts'), findsOneWidget);
    expect(find.text('0'), findsNothing);
    expect(find.text('9+'), findsOneWidget);
  });

  test('IndividualBar stores chart point values', () {
    final bar = IndividualBar(x: 2, y: 42.5);

    expect(bar.x, 2);
    expect(bar.y, 42.5);
  });
}
