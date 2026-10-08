import 'dart:convert';

import 'package:HPGM/api/farmer_api.dart';
import 'package:HPGM/config/api_config.dart';
import 'package:HPGM/Services/token_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body, int status) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final api = FarmerApi.instance;
  late List<http.Request> requests;

  void respondWith(http.Response Function(http.Request) handler) {
    FarmerApi.setHttpClientForTesting(
      MockClient((request) async {
        requests.add(request);
        return handler(request);
      }),
    );
  }

  setUp(() {
    requests = [];
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    FarmerApi.onUnauthorized = null;
  });

  tearDown(() {
    FarmerApi.resetHttpClientForTesting();
    FarmerApi.onUnauthorized = null;
  });

  group('login', () {
    test('stores token, expiry and farmer details', () async {
      respondWith(
        (_) => _json({
          'token': 'tok-123',
          'expires_at': '2030-01-01T00:00:00Z',
          'farmer': {
            'id': 5,
            'name': 'Jane Farmer',
            'email': 'jane@example.com',
            'role': 'farmer',
          },
        }, 200),
      );

      final farmer = await api.login('jane@example.com', 'secret123');

      expect(farmer['id'], 5);
      expect(await TokenStorage.getToken(), 'tok-123');
      expect(await TokenStorage.getExpiresAt(), DateTime.utc(2030));
      expect(await TokenStorage.getUserId(), '5');
      expect(await TokenStorage.getDisplayName(), 'Jane Farmer');

      final req = requests.single;
      expect(req.method, 'POST');
      expect(req.url.toString(), '${ApiConfig.baseUrl}/login');
      expect(req.headers['Accept'], 'application/json');
      expect(req.headers.containsKey('Authorization'), isFalse);
      expect(jsonDecode(req.body), {
        'email': 'jane@example.com',
        'password': 'secret123',
      });
    });

    test('rejects accounts that are not farmers', () async {
      respondWith(
        (_) => _json({
          'token': 'tok',
          'expires_at': '2030-01-01T00:00:00Z',
          'farmer': {'id': 1, 'name': 'Admin', 'role': 'admin'},
        }, 200),
      );

      await expectLater(
        api.login('a@example.com', 'x'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
      );
      expect(await TokenStorage.getToken(), isNull);
    });

    test('403 pending approval keeps the server message', () async {
      respondWith(
        (_) => _json({
          'message': 'Your account is awaiting administrator approval.',
        }, 403),
      );

      await expectLater(
        api.login('a@example.com', 'x'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('awaiting administrator approval'),
          ),
        ),
      );
    });

    test('401 on login does not trigger the session-ended handler', () async {
      var redirected = false;
      FarmerApi.onUnauthorized = () => redirected = true;
      respondWith((_) => _json({'message': 'Invalid credentials.'}, 401));

      await expectLater(
        api.login('a@example.com', 'wrong'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
      );
      expect(redirected, isFalse);
    });
  });

  test('protected calls send the bearer token', () async {
    await TokenStorage.saveLoginData(token: 'tok-abc');
    respondWith(
      (_) => _json({
        'success': true,
        'message': 'OK',
        'data': {'id': 5, 'email': 'jane@example.com'},
      }, 200),
    );

    final profile = await api.profile();

    expect(profile['id'], 5);
    expect(requests.single.headers['Authorization'], 'Bearer tok-abc');
  });

  test('401 on a protected call clears the session and redirects', () async {
    await TokenStorage.saveLoginData(token: 'tok-abc');
    var redirected = false;
    FarmerApi.onUnauthorized = () => redirected = true;
    respondWith((_) => _json({'message': 'Unauthenticated.'}, 401));

    await expectLater(api.profile(), throwsA(isA<ApiException>()));
    expect(redirected, isTrue);
    expect(await TokenStorage.getToken(), isNull);
  });

  test('422 exposes field errors', () async {
    respondWith(
      (_) => _json({
        'message': 'The email field is required.',
        'errors': {
          'email': ['Email address is required.'],
          'telephone': ['Telephone is required.'],
        },
      }, 422),
    );

    try {
      await api.register(
        name: 'Jane',
        email: '',
        telephone: '',
        password: 'password1',
        passwordConfirmation: 'password1',
      );
      fail('expected ApiException');
    } on ApiException catch (e) {
      expect(e.status, 422);
      expect(e.fieldError('email'), 'Email address is required.');
      expect(e.fieldError('telephone'), 'Telephone is required.');
      expect(e.fieldError('password'), isNull);
    }
  });

  test('non-JSON error bodies still produce an ApiException', () async {
    respondWith((_) => http.Response('<html>Server Error</html>', 500));

    await expectLater(
      api.forgotPassword('a@example.com'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.status, 'status', 500)
            .having((e) => e.message, 'message', contains('Server error')),
      ),
    );
  });

  test('logout clears local session even if the server call fails', () async {
    await TokenStorage.saveLoginData(token: 'tok-abc');
    respondWith((_) => http.Response('', 500));

    await api.logout();

    expect(await TokenStorage.getToken(), isNull);
  });

  group('ApiPage', () {
    test('parses envelope B (data + meta)', () async {
      await TokenStorage.saveLoginData(token: 't');
      respondWith(
        (_) => _json({
          'data': [
            {'id': 1, 'name': 'North', 'hives_count': 4},
          ],
          'meta': {'current_page': 1, 'last_page': 3, 'per_page': 25, 'total': 51},
        }, 200),
      );

      final page = await api.apiaries();

      expect(page.items.single['name'], 'North');
      expect(page.currentPage, 1);
      expect(page.lastPage, 3);
      expect(page.total, 51);
      expect(page.hasMore, isTrue);
      expect(requests.single.url.queryParameters, {'page': '1', 'per_page': '25'});
    });

    test('parses envelope A (paginator inside data)', () async {
      await TokenStorage.saveLoginData(token: 't');
      respondWith(
        (_) => _json({
          'success': true,
          'message': 'OK',
          'data': {
            'data': [
              {'hive_id': 12, 'brood_section': 35.0},
            ],
            'current_page': 2,
            'last_page': 2,
            'per_page': 50,
            'total': 51,
          },
        }, 200),
      );

      final page = await api.readings(
        12,
        'temperature',
        from: DateTime(2026, 9, 1),
        page: 2,
      );

      expect(page.items.single['brood_section'], 35.0);
      expect(page.hasMore, isFalse);
      final query = requests.single.url.queryParameters;
      expect(requests.single.url.path, endsWith('/hives/12/temperature'));
      expect(query['from'], startsWith('2026-09-01'));
      expect(query['page'], '2');
    });
  });
}
