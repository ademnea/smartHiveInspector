import 'package:HPGM/Services/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('saveLoginData stores token, user fields, and profile payload', () async {
    await TokenStorage.saveLoginData(
      token: 'abc-token',
      userId: '42',
      username: 'keeper@example.com',
      displayName: 'Hive Keeper',
      role: 'manager',
      profile: {
        'user': {
          'id': 42,
          'name': 'Hive Keeper',
          'email': 'keeper@example.com',
          'role': 'manager',
        },
      },
    );

    expect(await TokenStorage.getToken(), 'abc-token');
    expect(await TokenStorage.getUserId(), '42');
    expect(await TokenStorage.getUsername(), 'keeper@example.com');
    expect(await TokenStorage.getDisplayName(), 'Hive Keeper');
    expect(await TokenStorage.getRole(), 'manager');

    final storedProfile = await TokenStorage.getStoredProfile();
    expect(storedProfile?['user']['name'], 'Hive Keeper');
    expect(storedProfile?['user']['email'], 'keeper@example.com');
  });

  test('clearLoginData removes saved authentication and profile data', () async {
    await TokenStorage.saveLoginData(
      token: 'abc-token',
      userId: '42',
      username: 'keeper@example.com',
      displayName: 'Hive Keeper',
      role: 'manager',
      profile: {
        'user': {
          'id': 42,
          'name': 'Hive Keeper',
          'email': 'keeper@example.com',
          'role': 'manager',
        },
      },
    );

    await TokenStorage.clearLoginData();

    expect(await TokenStorage.getToken(), isNull);
    expect(await TokenStorage.getUserId(), isNull);
    expect(await TokenStorage.getUsername(), isNull);
    expect(await TokenStorage.getDisplayName(), isNull);
    expect(await TokenStorage.getRole(), isNull);
    expect(await TokenStorage.getStoredProfile(), isNull);
  });
}
