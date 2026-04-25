import 'package:HPGM/bee_counter/foraging_efficiency_metric.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ForagingEfficiencyMetric.fromJson maps stored metric values', () {
    final metric = ForagingEfficiencyMetric.fromJson({
      'date': '2026-04-25T10:00:00.000',
      'totalBeesIn': 100,
      'totalBeesOut': 80,
      'netChange': 20,
      'totalActivity': 180,
      'temperature': 25.5,
      'humidity': 60.0,
      'windSpeed': 3.5,
      'efficiencyScore': 82.4,
      'peakTimePeriod': '08:00-10:00',
      'returnRate': 1.25,
    });

    expect(metric.date, DateTime.parse('2026-04-25T10:00:00.000'));
    expect(metric.totalBeesIn, 100);
    expect(metric.totalBeesOut, 80);
    expect(metric.netChange, 20);
    expect(metric.peakTimePeriod, '08:00-10:00');
    expect(metric.returnRate, 1.25);
  });

  test('ForagingEfficiencyMetric.toJson emits persisted fields', () {
    final metric = ForagingEfficiencyMetric(
      date: DateTime(2026, 4, 25, 10),
      totalBeesIn: 100,
      totalBeesOut: 80,
      netChange: 20,
      totalActivity: 180,
      temperature: 25.5,
      humidity: 60.0,
      windSpeed: 3.5,
      efficiencyScore: 82.4,
      peakTimePeriod: '08:00-10:00',
      returnRate: 1.25,
    );

    final json = metric.toJson();

    expect(json['totalBeesIn'], 100);
    expect(json['totalActivity'], 180);
    expect(json['efficiencyScore'], 82.4);
  });

  test('ForagingEfficiencyMetric.copyWith replaces selected values', () {
    final metric = ForagingEfficiencyMetric(
      date: DateTime(2026, 4, 25, 10),
      totalBeesIn: 100,
      totalBeesOut: 80,
      netChange: 20,
      totalActivity: 180,
      temperature: 25.5,
      humidity: 60.0,
      windSpeed: 3.5,
      efficiencyScore: 82.4,
      peakTimePeriod: '08:00-10:00',
      returnRate: 1.25,
    );

    final updated = metric.copyWith(totalBeesIn: 110, efficiencyScore: 90);

    expect(updated.totalBeesIn, 110);
    expect(updated.totalBeesOut, 80);
    expect(updated.efficiencyScore, 90);
    expect(updated.peakTimePeriod, '08:00-10:00');
    expect(updated.returnRate, 1.25);
  });

  test('ForagingEfficiencyCalculator scores optimal periods higher than poor conditions', () {
    final optimal = ForagingEfficiencyCalculator.calculateEfficiencyScore(
      totalBeesIn: 120,
      totalBeesOut: 80,
      temperature: 25,
      windSpeed: 1,
      timestamp: DateTime(2026, 4, 25, 8),
    );

    final poor = ForagingEfficiencyCalculator.calculateEfficiencyScore(
      totalBeesIn: 10,
      totalBeesOut: 30,
      temperature: 40,
      windSpeed: 10,
      timestamp: DateTime(2026, 4, 25, 23),
    );

    expect(optimal, greaterThan(poor));
    expect(optimal, inInclusiveRange(0, 100));
    expect(poor, inInclusiveRange(0, 100));
  });
}
