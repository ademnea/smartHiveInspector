import 'package:HPGM/Services/token_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('saveLoginData stores token, expiry, user fields, and profile', () async {
    final expiresAt = DateTime.utc(2030, 1, 1);
    await TokenStorage.saveLoginData(
      token: 'abc-token',
      expiresAt: expiresAt,
      userId: '42',
      username: 'keeper@example.com',
      displayName: 'Hive Keeper',
      role: 'farmer',
      profile: {'id': 42, 'name': 'Hive Keeper', 'role': 'farmer'},
    );

    expect(await TokenStorage.getToken(), 'abc-token');
    expect(await TokenStorage.getExpiresAt(), expiresAt);
    expect(await TokenStorage.getUserId(), '42');
    expect(await TokenStorage.getUsername(), 'keeper@example.com');
    expect(await TokenStorage.getDisplayName(), 'Hive Keeper');
    expect(await TokenStorage.getRole(), 'farmer');
    expect((await TokenStorage.getStoredProfile())?['name'], 'Hive Keeper');
  });

  test('token is kept out of SharedPreferences', () async {
    await TokenStorage.saveLoginData(token: 'secret-token');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_token'), isNull);
  });

  test('hasValidSession follows expires_at', () async {
    await TokenStorage.saveLoginData(
      token: 't',
      expiresAt: DateTime.now().add(const Duration(days: 30)),
    );
    expect(await TokenStorage.hasValidSession(), isTrue);

    await TokenStorage.saveLoginData(
      token: 't',
      expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
    );
    expect(await TokenStorage.hasValidSession(), isFalse);
  });

  test('a token without an expiry is treated as expired', () async {
    await TokenStorage.saveLoginData(token: 't');

    expect(await TokenStorage.isLoggedIn(), isTrue);
    expect(await TokenStorage.hasValidSession(), isFalse);
  });

  test('clearLoginData removes the session and profile data', () async {
    SharedPreferences.setMockInitialValues({'auth_token': 'legacy-token'});
    await TokenStorage.saveLoginData(
      token: 'abc-token',
      expiresAt: DateTime.utc(2030),
      userId: '42',
      username: 'keeper@example.com',
      displayName: 'Hive Keeper',
      role: 'farmer',
      profile: {'id': 42},
    );

    await TokenStorage.clearLoginData();

    final prefs = await SharedPreferences.getInstance();
    expect(await TokenStorage.getToken(), isNull);
    expect(await TokenStorage.getExpiresAt(), isNull);
    expect(await TokenStorage.getUserId(), isNull);
    expect(await TokenStorage.getUsername(), isNull);
    expect(await TokenStorage.getDisplayName(), isNull);
    expect(await TokenStorage.getRole(), isNull);
    expect(await TokenStorage.getStoredProfile(), isNull);
    expect(prefs.getString('auth_token'), isNull);
  });
}
