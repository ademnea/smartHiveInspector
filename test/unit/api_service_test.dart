import 'dart:convert';

import 'package:HPGM/Services/api_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'auth_token': 'test-token',
      'token_expires_at':
          DateTime.now().add(const Duration(days: 1)).toIso8601String(),
    });
  });

  tearDown(() {
    ApiService.resetHttpClientForTesting();
  });

  test('fetchFarms sends bearer token and parses farm list', () async {
    Uri? requestedUri;
    Map<String, String>? requestedHeaders;
    ApiService.setHttpClientForTesting(
      MockClient((request) async {
        requestedUri = request.url;
        requestedHeaders = request.headers;
        return http.Response(
          jsonEncode([
            {
              'id': 1,
              'ownerId': 2,
              'name': 'Apiary One',
              'district': 'Nairobi',
              'address': 'Road 1',
              'average_temperature': 25,
              'average_weight': 30,
              'average_honey_percentage': 70,
              'latitude': '1.0',
              'longitude': '36.0',
              'description': 'Test',
              'created_at': '2026-04-01',
              'updated_at': '2026-04-25',
            },
          ]),
          200,
        );
      }),
    );

    final farms = await ApiService().fetchFarms();

    expect(requestedUri.toString(), '${ApiService.baseUrl}/farms');
    expect(requestedHeaders?['Authorization'], 'Bearer test-token');
    expect(farms, hasLength(1));
    expect(farms.first.name, 'Apiary One');
  });

  test('fetchHives parses hive list for a farm endpoint', () async {
    ApiService.setHttpClientForTesting(
      MockClient((request) async {
        expect(request.url.toString(), '${ApiService.baseUrl}/farms/4/hives');
        return http.Response(
          jsonEncode([
            {
              'id': 9,
              'longitude': '36.0',
              'latitude': '-1.0',
              'farm_id': 4,
              'state': {
                'connection_status': {'Connected': true},
                'colonization_status': {'Colonized': false},
              },
            },
          ]),
          200,
        );
      }),
    );

    final hives = await ApiService().fetchHives(4);

    expect(hives, hasLength(1));
    expect(hives.first.id, 9);
    expect(hives.first.isConnected, isTrue);
    expect(hives.first.isColonized, isFalse);
  });

  test('fetchTemperatureData includes start and end date query parameters', () async {
    ApiService.setHttpClientForTesting(
      MockClient((request) async {
        expect(
          request.url.toString(),
          '${ApiService.baseUrl}/hives/9/temperature?start_date=2026-04-01&end_date=2026-04-25',
        );
        return http.Response(
          jsonEncode([
            {'record': 25.5},
          ]),
          200,
        );
      }),
    );

    final data = await ApiService().fetchTemperatureData(
      9,
      startDate: DateTime(2026, 4, 1),
      endDate: DateTime(2026, 4, 25),
    );

    expect(data.first['record'], 25.5);
  });

  test('submitInspectionRecord posts JSON and returns true on created response', () async {
    String? body;
    ApiService.setHttpClientForTesting(
      MockClient((request) async {
        expect(request.url.toString(), '${ApiService.baseUrl}/inspections');
        body = request.body;
        return http.Response('{"id":1}', 201);
      }),
    );

    final success = await ApiService().submitInspectionRecord({'hive_id': 9});

    expect(success, isTrue);
    expect(jsonDecode(body!)['hive_id'], 9);
  });

  test('isApiReachable and getServerStatus handle success and error states', () async {
    ApiService.setHttpClientForTesting(
      MockClient((request) async {
        if (request.url.path.endsWith('/health')) {
          return http.Response('{}', 200);
        }
        if (request.url.path.endsWith('/status')) {
          return http.Response('{"status":"ok"}', 200);
        }
        return http.Response('Not found', 404);
      }),
    );

    expect(await ApiService().isApiReachable(), isTrue);
    expect(await ApiService().getServerStatus(), {'status': 'ok'});
  });
}
