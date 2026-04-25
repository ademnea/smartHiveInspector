import 'package:HPGM/utils/app_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DateTimeUtils', () {
    test('startOfDay returns midnight for the given date', () {
      final date = DateTime(2026, 4, 25, 15, 42, 10);

      expect(DateTimeUtils.startOfDay(date), DateTime(2026, 4, 25));
    });

    test('formats readable and API dates', () {
      final date = DateTime(2026, 4, 25, 9, 5);

      expect(DateTimeUtils.formatReadable(date), 'April 25, 2026');
      expect(DateTimeUtils.formatAPIDate(date), '2026-04-25');
      expect(DateTimeUtils.formatDateTime(date), '25/4/2026 9:05');
    });

    test('calculates whole calendar days between two dates', () {
      final from = DateTime(2026, 4, 20, 23);
      final to = DateTime(2026, 4, 25, 1);

      expect(DateTimeUtils.daysBetween(from, to), 5);
    });
  });

  group('StringUtils', () {
    test('capitalizes words and preserves spacing', () {
      expect(StringUtils.capitalize('hive keeper'), 'Hive Keeper');
      expect(StringUtils.capitalize(''), '');
    });

    test('truncates and shortens long strings', () {
      expect(StringUtils.truncate('beekeeper', 3), 'bee...');
      expect(StringUtils.shortenId('abcdef123456', 6), 'abcdef...');
    });

    test('removes special characters', () {
      expect(StringUtils.removeSpecialChars('Hive #42! OK'), 'Hive 42 OK');
    });
  });

  group('MathUtils', () {
    test('calculates average, min, max, power, and clamp', () {
      expect(MathUtils.average([2, 4, 6]), 4);
      expect(MathUtils.average([]), 0);
      expect(MathUtils.max([2, 9, 4]), 9);
      expect(MathUtils.min([2, 9, 4]), 2);
      expect(MathUtils.pow(3, 3), 27);
      expect(MathUtils.clamp(12, 0, 10), 10);
      expect(MathUtils.clamp(-2, 0, 10), 0);
      expect(MathUtils.clamp(6, 0, 10), 6);
    });

    test('rounds to decimal places', () {
      expect(MathUtils.roundToDecimalPlaces(3.14159, 2), 3.14);
    });
  });

  group('ColorUtils', () {
    test('lightens and darkens colors', () {
      const color = Color.fromARGB(255, 100, 150, 200);

      expect(ColorUtils.lighten(color, 50), const Color.fromARGB(255, 178, 203, 228));
      expect(ColorUtils.darken(color, 50), const Color.fromARGB(255, 50, 75, 100));
    });

    test('detects dark colors and picks contrasting text', () {
      expect(ColorUtils.isDarkColor(Colors.black), isTrue);
      expect(ColorUtils.isDarkColor(Colors.white), isFalse);
      expect(ColorUtils.contrastingTextColor(Colors.black), Colors.white);
      expect(ColorUtils.contrastingTextColor(Colors.white), Colors.black);
    });
  });

  group('FormatUtils', () {
    test('formats common display values', () {
      expect(FormatUtils.formatDate(DateTime(2026, 4, 25)), '25/4/2026');
      expect(FormatUtils.formatPercentage(73.456), '73.5%');
      expect(FormatUtils.formatWeight(12.345), '12.3 kg');
      expect(FormatUtils.formatWeight(12.345, unit: 'lb'), '12.3 lb');
      expect(FormatUtils.formatDuration(const Duration(days: 2, hours: 3)), '2d 3h');
      expect(FormatUtils.formatDuration(const Duration(hours: 3, minutes: 4)), '3h 4m');
      expect(FormatUtils.formatDuration(const Duration(minutes: 3, seconds: 4)), '3m 4s');
      expect(FormatUtils.formatDuration(const Duration(seconds: 9)), '9s');
      expect(FormatUtils.formatTemperature(25.36), startsWith('25.4'));
    });
  });
}
