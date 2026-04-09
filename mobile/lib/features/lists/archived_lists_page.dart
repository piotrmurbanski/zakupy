import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import 'list_detail_page.dart';

class ArchivedListsPage extends StatefulWidget {
  const ArchivedListsPage({
    required this.apiClient,
    required this.currentUserId,
    this.onUnauthorized,
    super.key,
  });

  final ApiClient apiClient;
  final String currentUserId;
  final Future<void> Function()? onUnauthorized;

  @override
  State<ArchivedListsPage> createState() => _ArchivedListsPageState();
}

class _ArchivedListsPageState extends State<ArchivedListsPage> {
  final List<ShoppingListSummary> _lists = <ShoppingListSummary>[];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  Future<void> _loadLists({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final lists = await widget.apiClient.fetchLists(includeArchived: true);

      if (!mounted) {
        return;
      }

      setState(() {
        _lists
          ..clear()
          ..addAll(lists.where((list) => list.isArchived));
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

  Future<void> _openList(ShoppingListSummary list) async {
    final didMutate = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => ListDetailPage(
          apiClient: widget.apiClient,
          listId: list.id,
          listName: list.name,
          isArchived: true,
          canManageList: list.isOwnedBy(widget.currentUserId),
          onUnauthorized: widget.onUnauthorized,
        ),
      ),
    );

    if (didMutate == true) {
      await _loadLists(silent: true);
    }
  }

  Future<void> _restoreList(ShoppingListSummary list) async {
    try {
      await widget.apiClient.restoreList(list.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restored ${list.name}.')),
      );
      await _loadLists(silent: true);
    } on ApiException catch (error) {
      if (error.isUnauthorized && widget.onUnauthorized != null) {
        await widget.onUnauthorized!();
        return;
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not restore list: ${error.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archived lists'),
        actions: [
          IconButton(
            onPressed: () => _loadLists(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadLists(silent: true),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _lists.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 200),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_errorMessage != null && _lists.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 120),
          Center(child: Text(_errorMessage!)),
        ],
      );
    }

    if (_lists.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 180),
          Center(child: Text('No archived lists.')),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _lists.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final list = _lists[index];

        return Card(
          child: ListTile(
            onTap: () => _openList(list),
            title: Text(list.name),
            subtitle: Text(
              list.isOwnedBy(widget.currentUserId)
                  ? 'Archived by you'
                  : 'Archived shared list',
            ),
            trailing: list.isOwnedBy(widget.currentUserId)
                ? TextButton(
                    onPressed: () => _restoreList(list),
                    child: const Text('Restore'),
                  )
                : const Icon(Icons.chevron_right),
          ),
        );
      },
    );
  }
}
