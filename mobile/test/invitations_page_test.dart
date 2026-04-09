import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zakupy_mobile/core/network/api_client.dart';
import 'package:zakupy_mobile/features/invitations/invitations_page.dart';

void main() {
  testWidgets('loads pending invitations and accepts one', (tester) async {
    final apiClient = _FakeApiClient();

    await tester.pumpWidget(
      MaterialApp(
        home: InvitationsPage(apiClient: apiClient),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Weekly groceries'), findsOneWidget);
    expect(find.textContaining('Owner'), findsOneWidget);

    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(apiClient.acceptCalls, 1);
    expect(find.text('Accepted Weekly groceries.'), findsOneWidget);
    expect(find.text('No pending invitations.'), findsOneWidget);
  });
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient()
      : super(baseUrl: 'http://localhost:3000', accessToken: 'token');

  int acceptCalls = 0;

  @override
  Future<List<ListInvitationSummary>> fetchInvitations() async {
    return <ListInvitationSummary>[
      ListInvitationSummary(
        id: 'invite_1',
        listId: 'list_1',
        listName: 'Weekly groceries',
        email: 'test@example.com',
        role: 'editor',
        status: 'pending',
        invitedByUser: const InvitationSender(
          id: 'user_1',
          email: 'owner@example.com',
          displayName: 'Owner',
        ),
        createdAt: DateTime.utc(2026, 4, 9, 10),
        updatedAt: DateTime.utc(2026, 4, 9, 10),
      ),
    ];
  }

  @override
  Future<void> acceptInvitation(String invitationId) async {
    acceptCalls += 1;
  }
}
