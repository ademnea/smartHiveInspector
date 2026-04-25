import 'package:HPGM/notifications/notification_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HiveNotification.copyWith keeps existing values and overrides selected ones', () {
    final notification = HiveNotification(
      id: 'n1',
      title: 'Temperature warning',
      message: 'Hive is warm',
      timestamp: DateTime(2026, 4, 25, 10),
      type: NotificationType.temperature,
      severity: NotificationSeverity.medium,
      hiveId: 7,
      data: {'temperature': 38},
    );

    final updated = notification.copyWith(isRead: true, severity: NotificationSeverity.high);

    expect(updated.id, 'n1');
    expect(updated.title, 'Temperature warning');
    expect(updated.isRead, isTrue);
    expect(updated.severity, NotificationSeverity.high);
    expect(updated.data?['temperature'], 38);
  });

  test('HiveNotification maps type to icon and severity to color', () {
    final cases = {
      NotificationType.temperature: Icons.thermostat,
      NotificationType.humidity: Icons.water_drop,
      NotificationType.weight: Icons.scale,
      NotificationType.weather: Icons.cloud,
      NotificationType.carbonDioxide: Icons.co2,
      NotificationType.connection: Icons.wifi,
      NotificationType.colonization: Icons.home,
    };

    for (final entry in cases.entries) {
      final notification = HiveNotification(
        id: entry.key.name,
        title: 'Title',
        message: 'Message',
        timestamp: DateTime.now(),
        type: entry.key,
        severity: NotificationSeverity.low,
        hiveId: 1,
      );

      expect(notification.icon, entry.value);
    }

    expect(
      HiveNotification(
        id: 'low',
        title: 'Title',
        message: 'Message',
        timestamp: DateTime.now(),
        type: NotificationType.weather,
        severity: NotificationSeverity.low,
        hiveId: 1,
      ).color,
      Colors.blue,
    );
    expect(
      HiveNotification(
        id: 'medium',
        title: 'Title',
        message: 'Message',
        timestamp: DateTime.now(),
        type: NotificationType.weather,
        severity: NotificationSeverity.medium,
        hiveId: 1,
      ).color,
      Colors.orange,
    );
    expect(
      HiveNotification(
        id: 'high',
        title: 'Title',
        message: 'Message',
        timestamp: DateTime.now(),
        type: NotificationType.weather,
        severity: NotificationSeverity.high,
        hiveId: 1,
      ).color,
      Colors.red,
    );
  });

  test('HiveNotification.timeAgo returns readable recent durations', () {
    final now = DateTime.now();

    expect(
      HiveNotification(
        id: 'seconds',
        title: 'Title',
        message: 'Message',
        timestamp: now.subtract(const Duration(seconds: 10)),
        type: NotificationType.weather,
        severity: NotificationSeverity.low,
        hiveId: 1,
      ).timeAgo,
      'Just now',
    );

    expect(
      HiveNotification(
        id: 'minutes',
        title: 'Title',
        message: 'Message',
        timestamp: now.subtract(const Duration(minutes: 5)),
        type: NotificationType.weather,
        severity: NotificationSeverity.low,
        hiveId: 1,
      ).timeAgo,
      '5 min ago',
    );
  });
}
