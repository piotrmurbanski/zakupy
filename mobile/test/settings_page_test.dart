import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakupy_mobile/features/auth/auth_profile_store.dart';
import 'package:zakupy_mobile/features/auth/settings_page.dart';

void main() {
  testWidgets('SettingsPage shows saved auth data and resets it', (
    tester,
  ) async {
    var resetCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          savedProfile: const SavedAuthProfile(
            baseUrl: 'http://localhost:3000',
            email: 'test@example.com',
          ),
          onResetLocalData: () async {
            resetCalls += 1;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Backend: http://localhost:3000'), findsOneWidget);
    expect(find.text('Email: test@example.com'), findsOneWidget);

    await tester.tap(find.text('Reset saved auth data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(resetCalls, 1);
  });
}
