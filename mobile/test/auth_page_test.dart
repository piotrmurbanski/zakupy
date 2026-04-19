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
      find.widgetWithText(TextFormField, 'Adres API'),
    );
    final emailField = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Email'),
    );

    expect(baseUrlField.controller?.text, 'http://localhost:3000');
    expect(emailField.controller?.text, 'test@example.com');
  });

  testWidgets('AuthPage shows Polish copy for the request-code step', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthPage(
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

    expect(
      find.text(
        'Podaj swój adres e-mail, aby otrzymać kod logowania. Na prawdziwym telefonie użyj adresu Tailscale albo Caddy zamiast localhost.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextFormField, 'Adres API'), findsOneWidget);
    expect(
      find.widgetWithText(
        TextFormField,
        'Nazwa wyświetlana (opcjonalnie)',
      ),
      findsOneWidget,
    );
    expect(find.text('Wyślij kod'), findsOneWidget);
  });
}
