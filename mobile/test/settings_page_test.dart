import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakupy_mobile/features/auth/auth_models.dart';
import 'package:zakupy_mobile/features/auth/auth_profile_store.dart';
import 'package:zakupy_mobile/features/auth/settings_page.dart';

void main() {
  testWidgets('SettingsPage shows saved auth data and current phone number', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          currentUser: _buildUser(phoneNumber: '+48123123123'),
          savedProfile: const SavedAuthProfile(
            baseUrl: 'http://localhost:3000',
            email: 'test@example.com',
          ),
          onUpdatePhoneNumber: (phoneNumber) async =>
              _buildUser(phoneNumber: phoneNumber),
          onResetLocalData: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Backend: http://localhost:3000'), findsOneWidget);
    expect(find.text('Email: test@example.com'), findsOneWidget);
    expect(find.text('test@example.com'), findsOneWidget);
    expect(find.text('Aktualnie zapisany numer: +48123123123'), findsOneWidget);
  });

  testWidgets('SettingsPage saves a valid phone number', (tester) async {
    String? savedPhoneNumber;

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          currentUser: _buildUser(),
          onUpdatePhoneNumber: (phoneNumber) async {
            savedPhoneNumber = phoneNumber;
            return _buildUser(phoneNumber: '+48123123123');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), ' +48 123 123 123 ');
    await tester.tap(find.text('Zapisz numer'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(savedPhoneNumber, ' +48 123 123 123 ');
    expect(find.text('Numer telefonu zapisany.'), findsOneWidget);
    expect(find.text('Aktualnie zapisany numer: +48123123123'), findsOneWidget);
  });

  testWidgets('SettingsPage validates phone number before saving', (
    tester,
  ) async {
    var saveCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          currentUser: _buildUser(),
          onUpdatePhoneNumber: (phoneNumber) async {
            saveCalls += 1;
            return _buildUser(phoneNumber: phoneNumber);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '123');
    await tester.tap(find.text('Zapisz numer'));
    await tester.pumpAndSettle();

    expect(saveCalls, 0);
    expect(
      find.text('Podaj numer w formacie międzynarodowym, np. +48123123123.'),
      findsOneWidget,
    );
  });

  testWidgets('SettingsPage disables actions while saving', (tester) async {
    final completer = Completer<AuthUser>();

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          currentUser: _buildUser(),
          onUpdatePhoneNumber: (_) => completer.future,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '+48123123123');
    await tester.tap(find.text('Zapisz numer'));
    await tester.pump();

    final filledButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Zapisz numer'),
    );
    final textField = tester.widget<TextField>(find.byType(TextField));

    expect(filledButton.onPressed, isNull);
    expect(textField.enabled, isFalse);

    completer.complete(_buildUser(phoneNumber: '+48123123123'));
    await tester.pumpAndSettle();
  });

  testWidgets('SettingsPage shows backend errors when saving fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          currentUser: _buildUser(),
          onUpdatePhoneNumber: (_) async {
            throw Exception('Nie udało się zapisać zmian.');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '+48123123123');
    await tester.tap(find.text('Zapisz numer'));
    await tester.pumpAndSettle();

    expect(find.text('Nie udało się zapisać zmian.'), findsOneWidget);
  });

  testWidgets('SettingsPage clears the saved phone number', (tester) async {
    String? clearedValue = 'unchanged';

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          currentUser: _buildUser(phoneNumber: '+48123123123'),
          onUpdatePhoneNumber: (phoneNumber) async {
            clearedValue = phoneNumber;
            return _buildUser(phoneNumber: null);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Usuń numer'));
    await tester.pumpAndSettle();

    expect(clearedValue, isNull);
    expect(find.text('Numer telefonu usunięty.'), findsOneWidget);
    expect(find.text('Brak zapisanego numeru telefonu.'), findsOneWidget);
  });

  testWidgets('SettingsPage resets saved auth data after confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var resetCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          currentUser: _buildUser(),
          savedProfile: const SavedAuthProfile(
            baseUrl: 'http://localhost:3000',
            email: 'test@example.com',
          ),
          onUpdatePhoneNumber: (phoneNumber) async =>
              _buildUser(phoneNumber: phoneNumber),
          onResetLocalData: () async {
            resetCalls += 1;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Wyczyść zapisane dane'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wyczyść'));
    await tester.pumpAndSettle();

    expect(resetCalls, 1);
  });
}

AuthUser _buildUser({String? phoneNumber}) {
  return AuthUser(
    id: 'user_1',
    email: 'test@example.com',
    displayName: 'Test User',
    phoneNumber: phoneNumber,
    createdAt: DateTime.parse('2026-03-29T10:00:00.000Z'),
    updatedAt: DateTime.parse('2026-03-29T10:00:00.000Z'),
  );
}
