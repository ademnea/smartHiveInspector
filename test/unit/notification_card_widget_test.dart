import 'package:HPGM/notifications/notification_card.dart';
import 'package:HPGM/notifications/notification_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
