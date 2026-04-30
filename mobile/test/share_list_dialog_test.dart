import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakupy_mobile/features/lists/share_list_dialog.dart';

void main() {
  test('in-memory store normalizes, deduplicates, and reorders recent emails',
      () async {
    final store = InMemoryShareEmailHistoryStore([
      'First@example.com',
      ' second@example.com ',
      'first@example.com',
      '',
    ]);

    expect(
      await store.readRecentEmails(),
      equals(const <String>['first@example.com', 'second@example.com']),
    );

    await store.rememberEmail('THIRD@example.com');
    await store.rememberEmail(' second@example.com ');
    await store.rememberEmail('   ');

    expect(
      await store.readRecentEmails(),
      equals(const <String>[
        'second@example.com',
        'third@example.com',
        'first@example.com',
      ]),
    );

    await store.removeEmail(' third@example.com ');
    await store.removeEmail('missing@example.com');

    expect(
      await store.readRecentEmails(),
      equals(const <String>['second@example.com', 'first@example.com']),
    );
  });

  testWidgets('long press removes a recent share email after confirmation',
      (tester) async {
    final store = InMemoryShareEmailHistoryStore([
      'test@example.com',
      'wife@example.com',
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showShareListDialog(
                    context,
                    historyStore: store,
                  ),
                  child: const Text('Share'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    expect(find.text('test@example.com'), findsOneWidget);

    await tester.longPress(find.text('test@example.com'));
    await tester.pumpAndSettle();

    expect(find.text('Usunąć adres?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Usuń'));
    await tester.pumpAndSettle();

    expect(find.text('test@example.com'), findsNothing);
    expect(find.text('wife@example.com'), findsOneWidget);
    expect(
      await store.readRecentEmails(),
      equals(const <String>['wife@example.com']),
    );
  });
}
