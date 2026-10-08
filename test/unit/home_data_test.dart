import 'package:HPGM/home.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HomeData.fromJson maps dashboard count, productive, and season data', () {
    final data = HomeData.fromJson(
      {
        'total_farms': 3,
        'total_hives': 12,
      },
      {
        'most_productive_farm': {'name': 'North Apiary'},
        'average_honey_percentage': 72,
        'average_weight': 31.5,
      },
      {
        'time_until_harvest': {
          'days': 14,
          'percentage_time_left': 35,
        },
      },
      {},
    );

    expect(data.farms, 3);
    expect(data.hives, 12);
    expect(data.apiaryName, 'North Apiary');
    expect(data.averageHoneyPercentage, 72.0);
    expect(data.averageWeight, 31.5);
    expect(data.daysToEndSeason, 14.0);
    expect(data.percentage_time_left, 35.0);
  });

  test('HomeData.fromApiaries sums hives and picks the busiest apiary', () {
    final data = HomeData.fromApiaries([
      {'id': 1, 'name': 'North', 'hives_count': 3},
      {'id': 2, 'name': 'River', 'hives_count': 7},
      {'id': 3, 'name': 'Hill'},
    ]);

    expect(data.farms, 3);
    expect(data.hives, 10);
    expect(data.apiaryName, 'River');
    expect(data.hasHarvestData, isFalse);
  });

  test('HomeData.fromApiaries handles a farmer with no apiaries', () {
    final data = HomeData.fromApiaries([]);

    expect(data.farms, 0);
    expect(data.hives, 0);
    expect(data.apiaryName, '--');
  });
}
