import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zakupy_mobile/features/auth/auth_page.dart';

void main() {
  testWidgets('AuthPage pre-fills the saved backend URL and email', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthPage(
          initialBaseUrl: 'http://localhost:3000',
          initialEmail: 'test@example.com',
          themeMode: ThemeMode.system,
          onThemeModeChanged: (_) {},
          onRequestCode: ({
            required String baseUrl,
            required String email,
            String? displayName,
          }) async {},
          onVerifyCode: ({
            required String baseUrl,
            required String email,
            required String code,
            String? displayName,
          }) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final baseUrlField = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'API base URL'),
    );
    final emailField = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Email'),
    );

    expect(baseUrlField.controller?.text, 'http://localhost:3000');
    expect(emailField.controller?.text, 'test@example.com');
  });
}
