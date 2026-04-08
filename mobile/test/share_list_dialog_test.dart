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
  });
}
