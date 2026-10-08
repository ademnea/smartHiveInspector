import 'dart:convert';

import 'package:HPGM/api/farmer_api.dart';
import 'package:HPGM/config/api_config.dart';
import 'package:HPGM/Services/auth_manager.dart';
import 'package:HPGM/Services/token_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final tomorrow = DateTime.now().add(const Duration(days: 1));

  setUp(() {
    AuthManager.resetHttpClientForTesting();
    FarmerApi.resetHttpClientForTesting();
    FarmerApi.onUnauthorized = null;
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() {
    AuthManager.resetHttpClientForTesting();
    FarmerApi.resetHttpClientForTesting();
    FarmerApi.onUnauthorized = null;
  });

  test('isAuthenticated returns false when no token is stored', () async {
    expect(await AuthManager.isAuthenticated(), isFalse);
    expect(await AuthManager.ensureValidToken(), isFalse);
  });

  test('ensureValidToken clears an expired token (no refresh endpoint)', () async {
    await TokenStorage.saveLoginData(
      token: 'old-token',
      expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
    );

    expect(await AuthManager.ensureValidToken(), isFalse);
    expect(await TokenStorage.getToken(), isNull);
  });

  test('ensureValidToken returns true for a stored unexpired token', () async {
    await TokenStorage.saveLoginData(token: 'valid-token', expiresAt: tomorrow);

    expect(await AuthManager.ensureValidToken(), isTrue);
    expect(await AuthManager.isAuthenticated(), isTrue);
  });

  test('authenticated GET adds bearer token and returns response', () async {
    await TokenStorage.saveLoginData(token: 'valid-token', expiresAt: tomorrow);

    Uri? requestedUri;
    Map<String, String>? requestedHeaders;
    AuthManager.setHttpClientForTesting(
      MockClient((request) async {
        requestedUri = request.url;

        requestedHeaders = request.headers;
        return http.Response('{"ok":true}', 200);
      }),
    );

    final response = await AuthManager.get(
      'http://example.com/api/profile',
      headers: {'X-Test': 'yes'},
    );

    expect(response?.statusCode, 200);
    expect(requestedUri.toString(), 'http://example.com/api/profile');
    expect(requestedHeaders?['Authorization'], 'Bearer valid-token');
    expect(requestedHeaders?['Accept'], 'application/json');
    expect(requestedHeaders?['Content-Type'], 'application/json');
    expect(requestedHeaders?['X-Test'], 'yes');
  });

  test('authenticated POST JSON-encodes map body', () async {
    await TokenStorage.saveLoginData(token: 'valid-token', expiresAt: tomorrow);

    String? requestBody;
    AuthManager.setHttpClientForTesting(
      MockClient((request) async {
        requestBody = request.body;
        return http.Response('{"created":true}', 201);
      }),
    );

    final response = await AuthManager.post(
      'http://example.com/api/farms',
      body: {'name': 'North Apiary'},
    );

    expect(response?.statusCode, 201);
    expect(jsonDecode(requestBody!)['name'], 'North Apiary');
  });

  test('authenticated PUT passes string body unchanged', () async {
    await TokenStorage.saveLoginData(token: 'valid-token', expiresAt: tomorrow);

    String? requestBody;
    AuthManager.setHttpClientForTesting(
      MockClient((request) async {
        requestBody = request.body;
        return http.Response('{"updated":true}', 200);
      }),
    );

    final response = await AuthManager.put(
      'http://example.com/api/farms/1',
      body: '{"name":"Updated"}',
    );

    expect(response?.statusCode, 200);
    expect(requestBody, '{"name":"Updated"}');
  });

  test('authenticated DELETE sends request with auth header', () async {
    await TokenStorage.saveLoginData(token: 'valid-token', expiresAt: tomorrow);

    String? method;
    AuthManager.setHttpClientForTesting(
      MockClient((request) async {
        method = request.method;
        expect(request.headers['Authorization'], 'Bearer valid-token');
        return http.Response('', 204);
      }),
    );

    final response = await AuthManager.delete('http://example.com/api/farms/1');

    expect(method, 'DELETE');
    expect(response?.statusCode, 204);
  });

  test('authenticatedRequest returns null for unsupported methods', () async {
    await TokenStorage.saveLoginData(token: 'valid-token', expiresAt: tomorrow);

    final response = await AuthManager.authenticatedRequest(
      method: 'PATCH',
      url: 'http://example.com/api/farms/1',
    );

    expect(response, isNull);
  });

  test('authenticatedRequest returns null when no valid token is available', () async {
    var called = false;
    AuthManager.setHttpClientForTesting(
      MockClient((request) async {
        called = true;
        return http.Response('should not happen', 200);
      }),
    );

    final response = await AuthManager.get('http://example.com/api/profile');

    expect(response, isNull);
    expect(called, isFalse);
  });

  test('a 401 from the farmer API clears the session and redirects', () async {
    await TokenStorage.saveLoginData(token: 'valid-token', expiresAt: tomorrow);
    var redirected = false;
    FarmerApi.onUnauthorized = () => redirected = true;
    AuthManager.setHttpClientForTesting(
      MockClient((request) async => http.Response('{"message":"Unauthenticated."}', 401)),
    );

    final response = await AuthManager.get('${ApiConfig.baseUrl}/profile');

    expect(response, isNull);
    expect(redirected, isTrue);
    expect(await TokenStorage.getToken(), isNull);
  });

  test('a 401 from another server does not end the session', () async {
    await TokenStorage.saveLoginData(token: 'valid-token', expiresAt: tomorrow);
    var redirected = false;
    FarmerApi.onUnauthorized = () => redirected = true;
    AuthManager.setHttpClientForTesting(
      MockClient((request) async => http.Response('', 401)),
    );

    final response = await AuthManager.get('http://old-server.example/api/v1/farms');

    expect(response?.statusCode, 401);
    expect(redirected, isFalse);
    expect(await TokenStorage.getToken(), 'valid-token');
  });

  test('logout clears token and cached auth state', () async {
    await TokenStorage.saveLoginData(
      token: 'valid-token',
      expiresAt: tomorrow,
      userId: '7',
    );
    FarmerApi.setHttpClientForTesting(
      MockClient((request) async => http.Response('{"message":"Logged out"}', 200)),
    );

    await AuthManager.logout();

    expect(await TokenStorage.getToken(), isNull);
    expect(await TokenStorage.getUserId(), isNull);
    expect(await AuthManager.isAuthenticated(), isFalse);
  });
}
