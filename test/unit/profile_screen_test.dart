import 'package:HPGM/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows loaded profile details from the injected profile response', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          token: 'test-token',
          profileFetcher: (_) async {
            return http.Response(
              '{"user":{"id":7,"name":"Test Farmer","email":"farmer@example.com","role":"admin"}}',
              200,
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Test Farmer'), findsOneWidget);
    expect(find.text('farmer@example.com'), findsOneWidget);
    expect(find.text('User ID: 7'), findsOneWidget);
    expect(find.text('admin'), findsOneWidget);
  });

  testWidgets('change password row explains that the feature is not wired yet', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          token: 'test-token',
          profileFetcher: (_) async {
            return http.Response(
              '{"user":{"id":7,"name":"Test Farmer","email":"farmer@example.com","role":"admin"}}',
              200,
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Change Password'));
    await tester.pump();

    expect(find.text('Change Password is not wired yet.'), findsOneWidget);
  });
}
