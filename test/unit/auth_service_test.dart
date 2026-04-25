import 'package:HPGM/Services/auth_services.dart';
import 'package:HPGM/Services/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('getToken reads from TokenStorage when memory token is empty', () async {
    await TokenStorage.saveLoginData(token: 'stored-token');

    expect(await AuthService.getToken(), 'stored-token');
  });

  test('isLoggedIn returns true when a token is stored', () async {
    await TokenStorage.saveLoginData(token: 'stored-token');

    expect(await AuthService.isLoggedIn(), isTrue);
  });
}
