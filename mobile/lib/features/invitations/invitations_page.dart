import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';

class InvitationsPage extends StatefulWidget {
  const InvitationsPage({
    required this.apiClient,
    this.onUnauthorized,
    super.key,
  });

  final ApiClient apiClient;
  final Future<void> Function()? onUnauthorized;

  @override
  State<InvitationsPage> createState() => _InvitationsPageState();
}

class _InvitationsPageState extends State<InvitationsPage> {
  final List<ListInvitationSummary> _invitations = <ListInvitationSummary>[];
  final Set<String> _pendingIds = <String>{};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInvitations();
  }

  Future<void> _loadInvitations({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final invitations = await widget.apiClient.fetchInvitations();

      if (!mounted) {
        return;
      }

      setState(() {
        _invitations
          ..clear()
          ..addAll(invitations);
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (error.isUnauthorized && widget.onUnauthorized != null) {
        await widget.onUnauthorized!();
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    }
  }

  Future<void> _acceptInvitation(ListInvitationSummary invitation) async {
    setState(() {
      _pendingIds.add(invitation.id);
    });

    try {
      await widget.apiClient.acceptInvitation(invitation.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _pendingIds.remove(invitation.id);
        _invitations.removeWhere((entry) => entry.id == invitation.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Accepted ${invitation.listName}.')),
      );
    } on ApiException catch (error) {
      if (error.isUnauthorized && widget.onUnauthorized != null) {
        await widget.onUnauthorized!();
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _pendingIds.remove(invitation.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not accept invitation: ${error.message}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invitations'),
        actions: [
          IconButton(
            onPressed: () => _loadInvitations(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadInvitations(silent: true),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _invitations.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 200),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_errorMessage != null && _invitations.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 120),
          Center(child: Text(_errorMessage!)),
        ],
      );
    }

    if (_invitations.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 180),
          Center(child: Text('No pending invitations.')),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _invitations.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final invitation = _invitations[index];
        final isPending = _pendingIds.contains(invitation.id);

        return Card(
          child: ListTile(
            title: Text(invitation.listName),
            subtitle: Text(
              'From ${invitation.invitedByUser.displayName} (${invitation.invitedByUser.email})',
            ),
            trailing: FilledButton(
              onPressed: isPending ? null : () => _acceptInvitation(invitation),
              child: const Text('Accept'),
            ),
          ),
        );
      },
    );
  }
}
