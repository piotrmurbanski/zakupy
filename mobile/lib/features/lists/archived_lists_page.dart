import 'dart:async';

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
  Timer? _refreshTimer;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadLists();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        _loadLists(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadLists({bool silent = false}) async {
    if (_isRefreshing) {
      return;
    }

    _isRefreshing = true;

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
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _openList(ShoppingListSummary list) async {
    final didMutate = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => ListDetailPage(
          apiClient: widget.apiClient,
          listId: list.id,
          listName: list.name,
          plannedFor: list.plannedFor,
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
        SnackBar(content: Text('Przywrócono listę ${list.name}.')),
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
        SnackBar(content: Text('Nie udało się przywrócić listy: ${error.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archiwum'),
        actions: [
          IconButton(
            onPressed: () => _loadLists(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Odśwież',
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
          Center(child: Text('Brak zarchiwizowanych list.')),
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
            title: _ArchivedListTitle(name: list.name, plannedFor: list.plannedFor),
            subtitle: Text(
              list.isOwnedBy(widget.currentUserId)
                  ? 'Zarchiwizowana przez Ciebie'
                  : 'Zarchiwizowana lista współdzielona',
            ),
            trailing: list.isOwnedBy(widget.currentUserId)
                ? TextButton(
                    onPressed: () => _restoreList(list),
                    child: const Text('Przywróć'),
                  )
                : const Icon(Icons.chevron_right),
          ),
        );
      },
    );
  }
}

class _ArchivedListTitle extends StatelessWidget {
  const _ArchivedListTitle({
    required this.name,
    required this.plannedFor,
  });

  final String name;
  final DateTime? plannedFor;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(name),
        if (plannedFor != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _formatArchivedDate(plannedFor!),
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
      ],
    );
  }
}

String _formatArchivedDate(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  const months = <String>[
    'STY',
    'LUT',
    'MAR',
    'KWI',
    'MAJ',
    'CZE',
    'LIP',
    'SIE',
    'WRZ',
    'PAŹ',
    'LIS',
    'GRU',
  ];
  return '$day-${months[local.month - 1]}';
}
