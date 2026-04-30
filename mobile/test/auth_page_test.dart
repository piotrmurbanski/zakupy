import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zakupy_mobile/features/auth/auth_page.dart';

void main() {
  testWidgets('AuthPage hides the saved backend URL behind a simple summary', (
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

    final emailField = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Email'),
    );

    expect(find.text('Zapisany serwer'), findsOneWidget);
    expect(find.text('http://localhost:3000'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Adres API'), findsNothing);
    expect(emailField.controller?.text, 'test@example.com');
  });

  testWidgets('AuthPage lets the user reveal the saved backend URL editor', (
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

    await tester.tap(find.text('Zmień'));
    await tester.pumpAndSettle();

    final baseUrlField = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Adres API'),
    );

    expect(baseUrlField.controller?.text, 'http://localhost:3000');
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
        'Podaj swój adres e-mail, aby otrzymać kod logowania.',
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
