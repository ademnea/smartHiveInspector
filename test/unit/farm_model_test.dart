import 'package:HPGM/farm_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Farm.fromJson supports ownerId casing and numeric conversions', () {
    final farm = Farm.fromJson({
      'id': 1,
      'OwnerId': 9,
      'name': 'North Apiary',
      'district': 'Nairobi',
      'address': 'Road 1',
      'average_temperature': 28,
      'average_weight': 41.5,
      'average_honey_percentage': 63,
      'latitude': '1.234',
      'longitude': 36.789,
      'description': 'Main farm',
      'created_at': '2026-04-01',
      'updated_at': '2026-04-25',
    });

    expect(farm.id, 1);
    expect(farm.ownerId, 9);
    expect(farm.average_temperature, 28.0);
    expect(farm.average_weight, 41.5);
    expect(farm.honeypercent, 63.0);
    expect(farm.latitude, 1.234);
    expect(farm.longitude, 36.789);
  });

  test('Farm.toJson emits API field names', () {
    final farm = Farm(
      id: 1,
      ownerId: 9,
      name: 'North Apiary',
      district: 'Nairobi',
      average_temperature: 28.0,
      average_weight: 41.5,
      honeypercent: 63.0,
      address: 'Road 1',
      latitude: 1.234,
      longitude: 36.789,
      description: 'Main farm',
      createdAt: '2026-04-01',
      updatedAt: '2026-04-25',
    );

    final json = farm.toJson();

    expect(json['ownerId'], 9);
    expect(json['average_honey_percentage'], 63.0);
    expect(json['longitude'], 36.789);
    expect(json.containsKey('longtitude'), isFalse);
  });

  test('Farm.fromJson accepts a farmer API apiary with missing fields', () {
    final farm = Farm.fromJson({'id': '4', 'name': 'North', 'hives_count': 6});

    expect(farm.id, 4);
    expect(farm.name, 'North');
    expect(farm.hivesCount, 6);
    expect(farm.district, '');
    expect(farm.address, '');
    expect(farm.latitude, isNull);
  });

  test('Farm.fromJson reads a real farmer API apiary', () {
    final farm = Farm.fromJson({
      'id': 7,
      'name': 'Mukono Central Apiary',
      'apiary_code': 'MCA',
      'country': 'UG',
      'region': 'Central Region',
      'district': null,
      'farmer_id': 10,
      'description': null,
      'managing_entity': 'Makerere University',
      'status': 'Active',
      'created_at': '2026-10-01T05:32:09.000000Z',
      'updated_at': '2026-10-01T05:32:09.000000Z',
      'deleted_at': null,
      'hives_count': 6,
    });

    expect(farm.id, 7);
    expect(farm.ownerId, 10);
    expect(farm.apiaryCode, 'MCA');
    expect(farm.status, 'Active');
    expect(farm.hivesCount, 6);
    // No district or address: fall back to region and country.
    expect(farm.district, 'Central Region');
    expect(farm.address, 'UG');
    expect(farm.description, isNull);
  });
}
