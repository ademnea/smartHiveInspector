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
}
