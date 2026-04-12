import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/collection_sync.dart';
import 'share_list_dialog.dart';

class ListDetailPage extends StatefulWidget {
  const ListDetailPage({
    required this.apiClient,
    required this.listId,
    this.listName,
    this.isArchived = false,
    this.canManageList = false,
    this.onUnauthorized,
    this.shareEmailHistoryStore,
    super.key,
  });

  final ApiClient apiClient;
  final String listId;
  final String? listName;
  final bool isArchived;
  final bool canManageList;
  final Future<void> Function()? onUnauthorized;
  final ShareEmailHistoryStore? shareEmailHistoryStore;

  @override
  State<ListDetailPage> createState() => _ListDetailPageState();
}

class _ListDetailPageState extends State<ListDetailPage> {
  final List<ShoppingListItem> _items = <ShoppingListItem>[];
  final List<ItemSuggestion> _suggestions = <ItemSuggestion>[];
  final Set<String> _pendingItemIds = <String>{};
  final Map<String, _PendingItemMutation> _pendingItemMutations =
      <String, _PendingItemMutation>{};

  late String _listName;
  late bool _isArchived;
  late final ShareEmailHistoryStore _shareEmailHistoryStore;
  bool _isLoading = true;
  bool _isSharing = false;
  bool _didMutateList = false;
  String? _errorMessage;
  int _temporaryItemCounter = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _shareEmailHistoryStore =
        widget.shareEmailHistoryStore ?? SecureShareEmailHistoryStore();
    _listName = widget.listName ?? 'List ${widget.listId}';
    _isArchived = widget.isArchived;
    _reloadItems();
    _reloadSuggestions();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        _reloadItems(silent: true);
        _reloadSuggestions(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _reloadItems({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final items = await widget.apiClient.fetchItems(widget.listId);

      if (!mounted) {
        return;
      }

      setState(() {
        final reconciledItems = _mergeFetchedItems(items);
        _items
          ..clear()
          ..addAll(reconciledItems);
        _isLoading = false;
        _errorMessage = null;
      });
    } on ApiException catch (error) {
      if (error.isUnauthorized && widget.onUnauthorized != null) {
        await widget.onUnauthorized!();
        return;
      }

      if (!mounted) {
        return;
      }

      final hasExistingItems = _items.isNotEmpty;
      final message = error.message;

      setState(() {
        _isLoading = false;
        if (!hasExistingItems) {
          _errorMessage = message;
        }
      });

      if (hasExistingItems) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Nie udało się odświeżyć produktów: $message')),
        );
      }
    }
  }

  Future<void> _reloadSuggestions({bool silent = false}) async {
    try {
      final suggestions = await widget.apiClient.fetchItemSuggestions();

      if (!mounted) {
        return;
      }

      setState(() {
        _suggestions
          ..clear()
          ..addAll(suggestions);
      });
    } on ApiException catch (error) {
      if (error.isUnauthorized && widget.onUnauthorized != null) {
        await widget.onUnauthorized!();
        return;
      }

      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nie udało się pobrać sugestii: ${error.message}'),
          ),
        );
      }
    }
  }

  Future<void> _createItemFromDraft(ItemDraft draft) async {
    final temporaryId = _nextTemporaryItemId();
    final optimisticItem = _buildOptimisticItem(
      id: temporaryId,
      draft: draft,
      sortOrder: _nextSortOrder(),
    );

    setState(() {
      _didMutateList = true;
      _pendingItemIds.add(temporaryId);
      _pendingItemMutations[temporaryId] = _PendingItemMutation.create(
        optimisticItem: optimisticItem,
      );
      _items.add(optimisticItem);
      _sortItems();
    });

    try {
      final createdItem = await widget.apiClient.createItem(
        widget.listId,
        draft,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _pendingItemIds.remove(temporaryId);
        _pendingItemMutations.remove(temporaryId);
        removeById(target: _items, id: temporaryId, idOf: (item) => item.id);
        upsertById(target: _items, value: createdItem, idOf: (item) => item.id);
        _sortItems();
      });

      unawaited(_reloadSuggestions(silent: true));
    } on ApiException catch (error) {
      if (error.isUnauthorized && widget.onUnauthorized != null) {
        await widget.onUnauthorized!();
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _pendingItemIds.remove(temporaryId);
        _pendingItemMutations.remove(temporaryId);
        removeById(target: _items, id: temporaryId, idOf: (item) => item.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Nie udało się dodać produktu: ${error.message}')),
      );
    }
  }

  Future<void> _addItem() async {
    final draft = await showDialog<ItemDraft>(
      context: context,
      builder: (context) {
        return const _ItemEditorDialog();
      },
    );

    if (draft == null) {
      return;
    }

    await _createItemFromDraft(draft);
  }

  Future<void> _editItem(ShoppingListItem item) async {
    final draft = await showDialog<ItemDraft>(
      context: context,
      builder: (context) {
        return _ItemEditorDialog(initialItem: item);
      },
    );

    if (draft == null) {
      return;
    }

    final existingIndex = _items.indexWhere((entry) => entry.id == item.id);
    if (existingIndex == -1) {
      return;
    }

    final previousItem = _items[existingIndex];
    final optimisticItem = previousItem.copyWith(
      name: draft.name,
      comment: draft.comment,
      quantity: draft.quantity,
      isChecked: draft.isChecked,
    );

    setState(() {
      _didMutateList = true;
      _pendingItemIds.add(item.id);
      _pendingItemMutations[item.id] = _PendingItemMutation.update(
        previousItem: previousItem,
        optimisticItem: optimisticItem,
      );
      _items[existingIndex] = optimisticItem;
      _sortItems();
    });

    try {
      final updatedItem = await widget.apiClient.updateItem(
        widget.listId,
        item.id,
        draft,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _pendingItemIds.remove(item.id);
        _pendingItemMutations.remove(item.id);
        upsertById(
          target: _items,
          value: updatedItem,
          idOf: (entry) => entry.id,
        );
        _sortItems();
      });

      unawaited(_reloadSuggestions(silent: true));
    } on ApiException catch (error) {
      if (error.isUnauthorized && widget.onUnauthorized != null) {
        await widget.onUnauthorized!();
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _pendingItemIds.remove(item.id);
        _pendingItemMutations.remove(item.id);
        upsertById(
          target: _items,
          value: previousItem,
          idOf: (entry) => entry.id,
        );
        _sortItems();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Nie udało się zapisać produktu: ${error.message}')),
      );
    }
  }

  Future<void> _toggleItem(ShoppingListItem item, bool? checked) async {
    if (checked == null) {
      return;
    }

    final existingIndex = _items.indexWhere((entry) => entry.id == item.id);
    if (existingIndex == -1) {
      return;
    }

    final optimisticItem = _items[existingIndex].toDraft().copyWith(
          isChecked: checked,
        );
    final previousItem = _items[existingIndex];

    setState(() {
      _didMutateList = true;
      _pendingItemIds.add(item.id);
      _pendingItemMutations[item.id] = _PendingItemMutation.update(
        previousItem: previousItem,
        optimisticItem: previousItem.copyWith(isChecked: checked),
      );
      _items[existingIndex] = previousItem.copyWith(isChecked: checked);
      _sortItems();
    });

    try {
      final updatedItem = await widget.apiClient.updateItem(
        widget.listId,
        item.id,
        optimisticItem,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _pendingItemIds.remove(item.id);
        _pendingItemMutations.remove(item.id);
        upsertById(
          target: _items,
          value: updatedItem,
          idOf: (entry) => entry.id,
        );
        _sortItems();
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
        _pendingItemIds.remove(item.id);
        _pendingItemMutations.remove(item.id);
        upsertById(
          target: _items,
          value: previousItem,
          idOf: (entry) => entry.id,
        );
        _sortItems();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Nie udało się zaktualizować produktu: ${error.message}')),
      );
    }
  }

  Future<void> _changeQuantity(ShoppingListItem item, int delta) async {
    final existingIndex = _items.indexWhere((entry) => entry.id == item.id);
    if (existingIndex == -1) {
      return;
    }

    final previousItem = _items[existingIndex];
    final nextQuantity = previousItem.quantity + delta;
    if (nextQuantity < 1) {
      return;
    }

    final optimisticDraft = previousItem.toDraft().copyWith(
          quantity: nextQuantity,
        );
    final optimisticItem = previousItem.copyWith(quantity: nextQuantity);

    setState(() {
      _didMutateList = true;
      _pendingItemIds.add(item.id);
      _pendingItemMutations[item.id] = _PendingItemMutation.update(
        previousItem: previousItem,
        optimisticItem: optimisticItem,
      );
      _items[existingIndex] = optimisticItem;
      _sortItems();
    });

    try {
      final updatedItem = await widget.apiClient.updateItem(
        widget.listId,
        item.id,
        optimisticDraft,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _pendingItemIds.remove(item.id);
        _pendingItemMutations.remove(item.id);
        upsertById(
          target: _items,
          value: updatedItem,
          idOf: (entry) => entry.id,
        );
        _sortItems();
      });

      if (delta > 0) {
        unawaited(_reloadSuggestions(silent: true));
      }
    } on ApiException catch (error) {
      if (error.isUnauthorized && widget.onUnauthorized != null) {
        await widget.onUnauthorized!();
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _pendingItemIds.remove(item.id);
        _pendingItemMutations.remove(item.id);
        upsertById(
          target: _items,
          value: previousItem,
          idOf: (entry) => entry.id,
        );
        _sortItems();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Nie udało się zmienić ilości: ${error.message}')),
      );
    }
  }

  Future<void> _addSuggestion(ItemSuggestion suggestion) async {
    ShoppingListItem? existingItem;

    for (final item in _items) {
      final matchesName = item.name.trim().toLowerCase() ==
          suggestion.name.trim().toLowerCase();
      final matchesComment = (item.comment?.trim().toLowerCase() ?? '') ==
          (suggestion.comment?.trim().toLowerCase() ?? '');

      if (!item.isChecked && matchesName && matchesComment) {
        existingItem = item;
        break;
      }
    }

    if (existingItem != null) {
      await _changeQuantity(existingItem, 1);
      return;
    }

    await _createItemFromDraft(
      ItemDraft(
        name: suggestion.name,
        comment: suggestion.comment,
        quantity: 1,
      ),
    );
  }

  Future<void> _deleteItem(ShoppingListItem item) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Usuń produkt'),
          content: Text('Usunąć "${item.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Anuluj'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Usuń'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    final existingIndex = _items.indexWhere((entry) => entry.id == item.id);
    if (existingIndex == -1) {
      return;
    }

    final previousItem = _items[existingIndex];

    setState(() {
      _didMutateList = true;
      _pendingItemIds.add(item.id);
      _pendingItemMutations[item.id] = _PendingItemMutation.delete(
        previousItem: previousItem,
      );
      _items.removeAt(existingIndex);
    });

    try {
      await widget.apiClient.deleteItem(widget.listId, item.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _pendingItemIds.remove(item.id);
        _pendingItemMutations.remove(item.id);
        removeById(target: _items, id: item.id, idOf: (entry) => entry.id);
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
        _pendingItemIds.remove(item.id);
        _pendingItemMutations.remove(item.id);
        _items.add(previousItem);
        _sortItems();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Nie udało się usunąć produktu: ${error.message}')),
      );
    }
  }

  Future<void> _shareList() async {
    if (_isSharing) {
      return;
    }

    final email = await showShareListDialog(
      context,
      historyStore: _shareEmailHistoryStore,
    );

    if (email == null) {
      return;
    }

    setState(() {
      _isSharing = true;
    });

    try {
      final result = await widget.apiClient.shareList(
        listId: widget.listId,
        email: email,
      );

      await _shareEmailHistoryStore.rememberEmail(email);

      if (!mounted) {
        return;
      }

      final message = result.member != null
          ? 'Udostępniono ${result.member!.user.email}.'
          : 'Udostępniono ${result.invitation!.email}. Lista pojawi się po zalogowaniu.';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on ApiException catch (error) {
      if (error.isUnauthorized && widget.onUnauthorized != null) {
        await widget.onUnauthorized!();
        return;
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  Future<void> _renameList() async {
    if (!widget.canManageList) {
      return;
    }

    final nextName = await showDialog<String>(
      context: context,
      builder: (context) {
        return _ListNameDialog(
          title: 'Zmień nazwę listy',
          initialValue: _listName,
          actionLabel: 'Zapisz',
        );
      },
    );

    if (nextName == null || nextName == _listName) {
      return;
    }

    try {
      final updatedList = await widget.apiClient.updateList(
        widget.listId,
        nextName,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _didMutateList = true;
        _listName = updatedList.name;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Zmieniono nazwę na ${updatedList.name}.')),
      );
    } on ApiException catch (error) {
      if (error.isUnauthorized && widget.onUnauthorized != null) {
        await widget.onUnauthorized!();
        return;
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Nie udało się zmienić nazwy listy: ${error.message}')),
      );
    }
  }

  Future<void> _toggleArchiveStatus() async {
    if (!widget.canManageList) {
      return;
    }

    try {
      final updatedList = _isArchived
          ? await widget.apiClient.restoreList(widget.listId)
          : await widget.apiClient.archiveList(widget.listId);

      if (!mounted) {
        return;
      }

      setState(() {
        _didMutateList = true;
        _isArchived = updatedList.isArchived;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updatedList.isArchived
                ? 'Lista przeniesiona do archiwum.'
                : 'Lista przywrócona.',
          ),
        ),
      );

      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (error.isUnauthorized && widget.onUnauthorized != null) {
        await widget.onUnauthorized!();
        return;
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isArchived
                ? 'Nie udało się przywrócić listy: ${error.message}'
                : 'Nie udało się zarchiwizować listy: ${error.message}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _listName;

    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        Navigator.of(context).pop(_didMutateList);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: () => Navigator.of(context).pop(_didMutateList),
          ),
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              onPressed: () => _reloadItems(),
              icon: const Icon(Icons.refresh),
            ),
            PopupMenuButton<_ListAction>(
              onSelected: (action) {
                if (action == _ListAction.share) {
                  _shareList();
                } else if (action == _ListAction.rename) {
                  _renameList();
                } else if (action == _ListAction.archive) {
                  _toggleArchiveStatus();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<_ListAction>(
                  value: _ListAction.share,
                  enabled: !_isSharing,
                  child: const Text('Udostępnij listę'),
                ),
                if (widget.canManageList)
                  const PopupMenuItem<_ListAction>(
                    value: _ListAction.rename,
                    child: Text('Zmień nazwę listy'),
                  ),
                if (widget.canManageList)
                  PopupMenuItem<_ListAction>(
                    value: _ListAction.archive,
                    child: Text(
                      _isArchived ? 'Przywróć listę' : 'Archiwizuj listę',
                    ),
                  ),
              ],
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _addItem,
          child: const Icon(Icons.add),
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            await _reloadItems(silent: true);
            await _reloadSuggestions(silent: true);
          },
          child: _buildBody(context),
        ),
      ),
    );
  }

  bool _isItemPending(String itemId) {
    return _pendingItemIds.contains(itemId);
  }

  Future<void> _onToggleRequested(ShoppingListItem item, bool? checked) async {
    if (_isItemPending(item.id)) {
      return;
    }

    await _toggleItem(item, checked);
  }

  Future<void> _onEditRequested(ShoppingListItem item) async {
    if (_isItemPending(item.id)) {
      return;
    }

    await _editItem(item);
  }

  Future<void> _onDeleteRequested(ShoppingListItem item) async {
    if (_isItemPending(item.id)) {
      return;
    }

    await _deleteItem(item);
  }

  Widget _buildItemTile(ShoppingListItem item) {
    final isPending = _isItemPending(item.id);

    return Card(
      child: ListTile(
        leading: Checkbox(
          value: item.isChecked,
          onChanged:
              isPending ? null : (checked) => _onToggleRequested(item, checked),
        ),
        title: Text(
          '${item.name} (${item.quantity})',
          style: TextStyle(
            decoration: item.isChecked
                ? TextDecoration.lineThrough
                : TextDecoration.none,
          ),
        ),
        subtitle: _buildSubtitle(item),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: isPending || item.quantity <= 1
                  ? null
                  : () => _changeQuantity(item, -1),
              icon: const Icon(Icons.remove_circle_outline),
              tooltip: 'Zmniejsz ilość',
            ),
            IconButton(
              onPressed: isPending ? null : () => _changeQuantity(item, 1),
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Zwiększ ilość',
            ),
            IconButton(
              onPressed: isPending ? null : () => _onEditRequested(item),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              onPressed: isPending ? null : () => _onDeleteRequested(item),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }

  void _sortItems() {
    _items.sort(_compareItems);
  }

  List<ShoppingListItem> _mergeFetchedItems(
    List<ShoppingListItem> fetchedItems,
  ) {
    final merged = List<ShoppingListItem>.from(fetchedItems);

    for (final entry in _pendingItemMutations.entries) {
      final itemId = entry.key;
      final mutation = entry.value;

      switch (mutation.type) {
        case _PendingItemMutationType.create:
          if (mutation.optimisticItem != null &&
              merged.every((item) => item.id != itemId)) {
            merged.add(mutation.optimisticItem!);
          }
          break;
        case _PendingItemMutationType.update:
          if (mutation.optimisticItem == null) {
            break;
          }

          upsertById(
            target: merged,
            value: mutation.optimisticItem!,
            idOf: (item) => item.id,
          );
          break;
        case _PendingItemMutationType.delete:
          removeById(target: merged, id: itemId, idOf: (item) => item.id);
          break;
      }
    }

    merged.sort(_compareItems);

    return merged;
  }

  int _compareItems(ShoppingListItem left, ShoppingListItem right) {
    final byChecked = left.isChecked == right.isChecked
        ? 0
        : left.isChecked
            ? 1
            : -1;
    if (byChecked != 0) {
      return byChecked;
    }

    final byOrder = left.sortOrder.compareTo(right.sortOrder);
    if (byOrder != 0) {
      return byOrder;
    }

    return left.createdAt.compareTo(right.createdAt);
  }

  int _nextSortOrder() {
    if (_items.isEmpty) {
      return 0;
    }

    return _items
            .map((item) => item.sortOrder)
            .reduce((left, right) => left > right ? left : right) +
        1;
  }

  String _nextTemporaryItemId() {
    _temporaryItemCounter += 1;
    return '__optimistic_item_$_temporaryItemCounter';
  }

  ShoppingListItem _buildOptimisticItem({
    required String id,
    required ItemDraft draft,
    required int sortOrder,
  }) {
    final now = DateTime.now().toUtc();

    return ShoppingListItem(
      id: id,
      listId: widget.listId,
      name: draft.name,
      comment: draft.comment,
      quantity: draft.quantity,
      isChecked: draft.isChecked,
      sortOrder: sortOrder,
      createdByUserId: 'pending',
      createdAt: now,
      updatedAt: now,
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 240),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_errorMessage != null && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 160),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Nie udało się wczytać produktów',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'Unknown error',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => _reloadItems(),
                  child: const Text('Spróbuj ponownie'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          const SizedBox(height: 160),
          const Center(child: Text('Brak produktów. Dodaj pierwszy.')),
          if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSuggestionsSection(context),
          ],
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        for (final item in _items) ...[
          _buildItemTile(item),
          const SizedBox(height: 8),
        ],
        if (_suggestions.isNotEmpty) _buildSuggestionsSection(context),
      ],
    );
  }

  Widget? _buildSubtitle(ShoppingListItem item) {
    if (item.comment == null || item.comment!.isEmpty) {
      return null;
    }

    return Text(item.comment!);
  }

  Widget _buildSuggestionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Sugestie',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Najczęściej dodawane produkty',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggestions
              .map(
                (suggestion) => ActionChip(
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.6),
                  label: Text(
                    suggestion.comment == null || suggestion.comment!.isEmpty
                        ? suggestion.name
                        : '${suggestion.name} • ${suggestion.comment}',
                  ),
                  onPressed: () => _addSuggestion(suggestion),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

enum _ListAction { share, rename, archive }

enum _PendingItemMutationType { create, update, delete }

class _PendingItemMutation {
  const _PendingItemMutation._({
    required this.type,
    this.previousItem,
    this.optimisticItem,
  });

  factory _PendingItemMutation.create({
    required ShoppingListItem optimisticItem,
  }) {
    return _PendingItemMutation._(
      type: _PendingItemMutationType.create,
      optimisticItem: optimisticItem,
    );
  }

  factory _PendingItemMutation.update({
    required ShoppingListItem previousItem,
    required ShoppingListItem optimisticItem,
  }) {
    return _PendingItemMutation._(
      type: _PendingItemMutationType.update,
      previousItem: previousItem,
      optimisticItem: optimisticItem,
    );
  }

  factory _PendingItemMutation.delete({
    required ShoppingListItem previousItem,
  }) {
    return _PendingItemMutation._(
      type: _PendingItemMutationType.delete,
      previousItem: previousItem,
    );
  }

  final _PendingItemMutationType type;
  final ShoppingListItem? previousItem;
  final ShoppingListItem? optimisticItem;
}

class _ItemEditorDialog extends StatefulWidget {
  const _ItemEditorDialog({this.initialItem});

  final ShoppingListItem? initialItem;

  @override
  State<_ItemEditorDialog> createState() => _ItemEditorDialogState();
}

class _ItemEditorDialogState extends State<_ItemEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late bool _isChecked;
  late final TextEditingController _commentController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialItem?.name ?? '',
    );
    _commentController = TextEditingController(
      text: widget.initialItem?.comment ?? '',
    );
    _isChecked = widget.initialItem?.isChecked ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    Navigator.of(context).pop(
      ItemDraft(
        name: _nameController.text.trim(),
        comment: _normalizedOptionalText(_commentController.text),
        quantity: widget.initialItem?.quantity ?? 1,
        isChecked: _isChecked,
      ),
    );
  }

  String? _normalizedOptionalText(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialItem != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edytuj produkt' : 'Dodaj produkt'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nazwa'),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final trimmed = value?.trim() ?? '';

                  if (trimmed.isEmpty) {
                    return 'Nazwa jest wymagana';
                  }

                  return null;
                },
              ),
              TextFormField(
                controller: _commentController,
                decoration: const InputDecoration(labelText: 'Komentarz'),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Anuluj'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Zapisz')),
      ],
    );
  }
}

class _ListNameDialog extends StatefulWidget {
  const _ListNameDialog({
    required this.title,
    required this.initialValue,
    required this.actionLabel,
  });

  final String title;
  final String initialValue;
  final String actionLabel;

  @override
  State<_ListNameDialog> createState() => _ListNameDialogState();
}

class _ListNameDialogState extends State<_ListNameDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nazwa listy'),
          maxLength: 100,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          validator: (value) {
            final trimmed = value?.trim() ?? '';

            if (trimmed.isEmpty) {
              return 'Nazwa listy jest wymagana';
            }

            if (trimmed.length > 100) {
              return 'Nazwa listy może mieć maksymalnie 100 znaków';
            }

            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Anuluj'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }
}
