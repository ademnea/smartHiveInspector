import 'package:HPGM/api/farmer_api.dart';
import 'package:HPGM/Services/auth_services.dart';
import 'package:HPGM/Services/token_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    FarmerApi.resetHttpClientForTesting();
  });

  tearDown(FarmerApi.resetHttpClientForTesting);

  test('getToken reads the stored token', () async {
    await TokenStorage.saveLoginData(token: 'stored-token');

    expect(await AuthService.getToken(), 'stored-token');
  });

  test('isLoggedIn requires an unexpired token', () async {
    await TokenStorage.saveLoginData(
      token: 'stored-token',
      expiresAt: DateTime.now().add(const Duration(days: 1)),
    );
    expect(await AuthService.isLoggedIn(), isTrue);

    await TokenStorage.saveLoginData(
      token: 'stored-token',
      expiresAt: DateTime.now().subtract(const Duration(days: 1)),
    );
    expect(await AuthService.isLoggedIn(), isFalse);
  });

  test('logout clears the session even when the server call fails', () async {
    await TokenStorage.saveLoginData(token: 'stored-token');
    FarmerApi.setHttpClientForTesting(
      MockClient((request) async => http.Response('', 500)),
    );

    expect(await AuthService.logout(), isTrue);
    expect(await TokenStorage.getToken(), isNull);
  });
}
