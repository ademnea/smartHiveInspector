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

  test('Hive.fromJson reads a farmer API hive', () {
    final hive = Hive.fromJson({
      'id': 7,
      'apiary_id': 7,
      'hive_code': 'HIVE-UG-MCA-001',
      'display_name': 'Mukono Colony 1',
      'name': null,
      'hive_type': 'Langstroth',
      'queen_status': 'Present',
      'status': 'active',
      'current_status': 'Active',
      'latitude': '0.34960000',
      'longitude': '32.75540000',
      'last_inspection_date': '2026-09-10T00:00:00.000000Z',
      'connected': null,
      'colonized': 1,
    });

    expect(hive.id, 7);
    expect(hive.farmId, 7);
    expect(hive.name, 'Mukono Colony 1');
    expect(hive.latitude, '0.34960000');
    expect(hive.currentStatus, 'Active');
    expect(hive.queenStatus, 'Present');
    expect(hive.connected, isNull);
    expect(hive.isConnected, isFalse);
    expect(hive.isColonized, isTrue);
    expect(hive.state, isNull);
  });

  test('Hive name falls back to the hive code, then the id', () {
    expect(
      Hive.fromJson({'id': 3, 'apiary_id': 1, 'hive_code': 'H-3'}).name,
      'H-3',
    );
    expect(Hive.fromJson({'id': 3, 'apiary_id': 1}).name, 'Hive 3');
  });
}
