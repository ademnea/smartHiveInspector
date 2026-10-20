import 'package:HPGM/reset_password.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reset code accepts only six digits', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ResetPasswordScreen(email: 'farmer@example.com')),
    );

    final codeField = find.byType(TextFormField).at(1);
    await tester.enterText(codeField, '12a345678');
    final editableText = tester.widget<EditableText>(
      find.descendant(of: codeField, matching: find.byType(EditableText)),
    );
    expect(editableText.controller.text, '123456');

    await tester.enterText(codeField, '123');
    await tester.tap(find.text('SET NEW PASSWORD'));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter the six-digit code from your email'),
      findsOneWidget,
    );
  });
}
