import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import 'list_detail_page.dart';
import 'share_list_dialog.dart';

class ListOverviewPage extends StatefulWidget {
  const ListOverviewPage({
    required this.apiClient,
    this.actions,
    this.header,
    super.key,
  });

  final ApiClient apiClient;
  final List<Widget>? actions;
  final Widget? header;

  @override
  State<ListOverviewPage> createState() => _ListOverviewPageState();
}

class _ListOverviewPageState extends State<ListOverviewPage> {
  final List<ShoppingListSummary> _lists = <ShoppingListSummary>[];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _reloadLists();
  }

  Future<void> _reloadLists({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final lists = await widget.apiClient.fetchLists();

      if (!mounted) {
        return;
      }

      setState(() {
        _lists
          ..clear()
          ..addAll(lists);
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = error.toString();
      final hasExistingLists = _lists.isNotEmpty;

      setState(() {
        _isLoading = false;
        if (!hasExistingLists) {
          _errorMessage = message;
        }
      });

      if (hasExistingLists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not refresh lists: $message')),
        );
      }
    }
  }

  void _openList(ShoppingListSummary list) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ListDetailPage(
          apiClient: widget.apiClient,
          listId: list.id,
          listName: list.name,
        ),
      ),
    );
  }

  Future<void> _shareList(ShoppingListSummary list) async {
    final email = await showShareListDialog(context);

    if (email == null) {
      return;
    }

    try {
      final result = await widget.apiClient.shareList(
        listId: list.id,
        email: email,
      );

      if (!mounted) {
        return;
      }

      final message = result.member != null
          ? 'Shared with ${result.member!.user.email}.'
          : 'Invitation sent to ${result.invitation!.email}.';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share list: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your lists'),
        actions: [
          IconButton(
            onPressed: () => _reloadLists(),
            icon: const Icon(Icons.refresh),
          ),
          ...?widget.actions,
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _reloadLists(silent: true),
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final header = widget.header;

    if (_isLoading && _lists.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (header != null) header,
          const SizedBox(height: 240),
          const Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_errorMessage != null && _lists.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (header != null) header,
          const SizedBox(height: 160),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Could not load your lists',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'Unknown error',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => _reloadLists(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_lists.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (header != null) header,
          const SizedBox(height: 160),
          const Center(child: Text('No shopping lists yet.')),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _lists.length + (header == null ? 0 : 1),
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (header != null && index == 0) {
          return header;
        }

        final listIndex = header == null ? index : index - 1;
        final list = _lists[listIndex];

        return Card(
          child: ListTile(
            onTap: () => _openList(list),
            title: Text(list.name),
            subtitle: Text('Updated ${_formatUpdatedAt(list.updatedAt)}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Share list',
                  onPressed: () => _shareList(list),
                  icon: const Icon(Icons.share_outlined),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatUpdatedAt(DateTime updatedAt) {
    final local = updatedAt.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$month/$day ${hour}:$minute';
  }
}
