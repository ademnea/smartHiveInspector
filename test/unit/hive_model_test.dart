import 'package:HPGM/hive_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Hive.fromJson parses nested hive state and convenience getters', () {
    final hive = Hive.fromJson({
      'id': '12',
      'longitude': '36.8',
      'latitude': '-1.3',
      'farm_id': '4',
      'created_at': '2026-04-01',
      'updated_at': '2026-04-25',
      'autoProcessingEnabled': false,
      'state': {
        'weight': {
          'record': 42,
          'honey_percentage': 67,
          'date_collected': '2026-04-25T08:00:00',
        },
        'temperature': {
          'interior_temperature': 34,
          'exterior_temperature': 26.5,
          'date_collected': '2026-04-25T07:00:00',
        },
        'humidity': {
          'interior_humidity': 55,
          'exterior_humidity': 61.5,
          'date_collected': '2026-04-25T06:00:00',
        },
        'carbon_dioxide': {
          'record': 500,
          'date_collected': '2026-04-25T05:00:00',
        },
        'connection_status': {'Connected': true},
        'colonization_status': {'Colonized': true},
      },
    });

    expect(hive.id, 12);
    expect(hive.farmId, 4);
    expect(hive.autoProcessingEnabled, isFalse);
    expect(hive.weight, 42.0);
    expect(hive.honeyLevel, 67.0);
    expect(hive.temperature, 34.0);
    expect(hive.exteriorTemperature, 26.5);
    expect(hive.humidity, 55.0);
    expect(hive.exteriorHumidity, 61.5);
    expect(hive.carbonDioxide, 500);
    expect(hive.isConnected, isTrue);
    expect(hive.isColonized, isTrue);
    expect(hive.name, 'Hive 12');
  });

  test('HiveData.fromApiHive maps missing state to safe defaults', () {
    final hive = Hive(
      id: 3,
      longitude: '36.8',
      latitude: '-1.3',
      farmId: 4,
    );

    final data = HiveData.fromApiHive(hive);

    expect(data.id, '3');
    expect(data.name, 'Hive 3');
    expect(data.status, 'Offline');
    expect(data.healthStatus, 'Not Colonized');
    expect(data.weight, 0.0);
    expect(data.temperature, 0.0);
    expect(data.honeyLevel, 0.0);
    expect(data.autoProcessingEnabled, isTrue);
  });
}
