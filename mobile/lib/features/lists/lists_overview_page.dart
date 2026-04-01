import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import 'list_detail_page.dart';

class ListsOverviewPage extends StatefulWidget {
  const ListsOverviewPage({
    required this.apiClient,
    super.key
  });

  final ApiClient apiClient;

  @override
  State<ListsOverviewPage> createState() => _ListsOverviewPageState();
}

class _ListsOverviewPageState extends State<ListsOverviewPage> {
  final List<ShoppingList> _lists = <ShoppingList>[];

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

      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _openList(ShoppingList list) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ListDetailPage(
          apiClient: widget.apiClient,
          initialList: list,
          listId: list.id
        )
      )
    );

    await _reloadLists(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your lists'),
        actions: [
          IconButton(
            onPressed: () => _reloadLists(),
            icon: const Icon(Icons.refresh)
          )
        ]
      ),
      body: RefreshIndicator(
        onRefresh: () => _reloadLists(silent: true),
        child: _buildBody(context)
      )
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading && _lists.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 240),
          Center(child: CircularProgressIndicator())
        ]
      );
    }

    if (_errorMessage != null && _lists.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          const SizedBox(height: 160),
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 12),
          Text(
            'Could not load your lists',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Unknown error',
            textAlign: TextAlign.center
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _reloadLists(),
            child: const Text('Retry')
          )
        ]
      );
    }

    if (_lists.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: const [
          SizedBox(height: 180),
          Icon(Icons.shopping_basket_outlined, size: 52),
          SizedBox(height: 12),
          Text(
            'No lists yet. Pull to refresh after another user shares one with you.',
            textAlign: TextAlign.center
          )
        ]
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
            leading: CircleAvatar(
              child: Text(list.name.characters.first.toUpperCase())
            ),
            title: Text(list.name),
            subtitle: const Text('Open items and manage sharing from the list menu'),
            trailing: const Icon(Icons.chevron_right)
          )
        );
      }
    );
  }
}
