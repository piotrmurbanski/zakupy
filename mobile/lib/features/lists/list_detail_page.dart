import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/item_icon.dart';
import '../../core/network/api_client.dart';
import '../../core/network/collection_sync.dart';
import 'share_list_dialog.dart';

String? _suggestedIconKeyForProduct({
  required Iterable<ItemSuggestion> suggestions,
  required String name,
  required String? comment,
}) {
  final normalizedName = name.trim().toLowerCase();
  if (normalizedName.isEmpty) {
    return null;
  }

  final normalizedComment = comment?.trim().toLowerCase() ?? '';
  final exactMatch = suggestions.where((suggestion) {
    final suggestionName = suggestion.name.trim().toLowerCase();
    final suggestionComment = suggestion.comment?.trim().toLowerCase() ?? '';
    return suggestionName == normalizedName &&
        suggestionComment == normalizedComment;
  });

  if (exactMatch.isNotEmpty) {
    return exactMatch.first.iconKey;
  }

  for (final suggestion in suggestions) {
    if (suggestion.name.trim().toLowerCase() == normalizedName) {
      return suggestion.iconKey;
    }
  }

  return null;
}

class ListDetailPage extends StatefulWidget {
  const ListDetailPage({
    required this.apiClient,
    required this.listId,
    this.listName,
    this.plannedFor,
    this.isArchived = false,
    this.canManageList = false,
    this.onUnauthorized,
    this.shareEmailHistoryStore,
    this.urlLauncher,
    super.key,
  });

  final ApiClient apiClient;
  final String listId;
  final String? listName;
  final DateTime? plannedFor;
  final bool isArchived;
  final bool canManageList;
  final Future<void> Function()? onUnauthorized;
  final ShareEmailHistoryStore? shareEmailHistoryStore;
  final Future<bool> Function(Uri uri)? urlLauncher;

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
  DateTime? _plannedFor;
  ListSharingMetadata? _sharing;
  late final ShareEmailHistoryStore _shareEmailHistoryStore;
  bool _isLoading = true;
  bool _isSharing = false;
  bool _isLaunchingWhatsApp = false;
  bool _didMutateList = false;
  String? _errorMessage;
  _WhatsAppDraft? _lastWhatsAppDraft;
  int _temporaryItemCounter = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _shareEmailHistoryStore =
        widget.shareEmailHistoryStore ?? SecureShareEmailHistoryStore();
    _listName = widget.listName ?? 'Lista';
    _plannedFor = widget.plannedFor;
    _reloadItems();
    _reloadSuggestions();
    _reloadListDetail(silent: true);
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        _reloadItems(silent: true);
        _reloadSuggestions(silent: true);
        _reloadListDetail(silent: true);
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

  Future<void> _reloadListDetail({bool silent = false}) async {
    if (!widget.canManageList) {
      return;
    }

    try {
      final detail = await widget.apiClient.fetchListDetail(widget.listId);

      if (!mounted) {
        return;
      }

      setState(() {
        _listName = detail.list.name;
        _plannedFor = detail.list.plannedFor;
        _sharing = detail.sharing;
      });
    } on ApiException catch (error) {
      if (error.isUnauthorized && widget.onUnauthorized != null) {
        await widget.onUnauthorized!();
        return;
      }

      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Nie udało się pobrać danych udostępniania: ${error.message}',
            ),
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
      _lastWhatsAppDraft = _WhatsAppDraft.added(_describeDraft(draft));
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
        return _ItemEditorDialog(suggestions: _suggestions);
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
        return _ItemEditorDialog(
          initialItem: item,
          suggestions: _suggestions,
        );
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
      iconKey: draft.iconKey,
    );

    setState(() {
      _didMutateList = true;
      _lastWhatsAppDraft =
          _WhatsAppDraft.updated(_describeItem(optimisticItem));
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
      _lastWhatsAppDraft = _WhatsAppDraft.updated(
        _describeItem(previousItem.copyWith(isChecked: checked)),
      );
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
    await _updateQuantity(item, delta);
  }

  Future<void> _updateQuantity(
    ShoppingListItem item,
    int delta, {
    String? iconKey,
  }) async {
    final existingIndex = _items.indexWhere((entry) => entry.id == item.id);
    if (existingIndex == -1) {
      return;
    }

    final previousItem = _items[existingIndex];
    final nextQuantity = previousItem.quantity + delta;
    if (nextQuantity < 1) {
      return;
    }

    final nextIconKey = iconKey ?? previousItem.iconKey;
    final optimisticDraft = previousItem.toDraft().copyWith(
          quantity: nextQuantity,
          iconKey: nextIconKey,
        );
    final optimisticItem = previousItem.copyWith(
      quantity: nextQuantity,
      iconKey: nextIconKey,
    );

    setState(() {
      _didMutateList = true;
      _lastWhatsAppDraft =
          _WhatsAppDraft.updated(_describeItem(optimisticItem));
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
      await _updateQuantity(
        existingItem,
        1,
        iconKey: suggestion.iconKey,
      );
      return;
    }

    await _createItemFromDraft(
      ItemDraft(
        name: suggestion.name,
        comment: suggestion.comment,
        quantity: 1,
        iconKey: suggestion.iconKey,
      ),
    );
  }

  Future<void> _deleteItem(
    ShoppingListItem item, {
    bool confirm = true,
  }) async {
    if (confirm) {
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
    }

    final existingIndex = _items.indexWhere((entry) => entry.id == item.id);
    if (existingIndex == -1) {
      return;
    }

    final previousItem = _items[existingIndex];

    setState(() {
      _didMutateList = true;
      _lastWhatsAppDraft = _WhatsAppDraft.removed(_describeItem(previousItem));
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

      unawaited(_reloadListDetail(silent: true));

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

  Future<void> _editList() async {
    if (!widget.canManageList) {
      return;
    }

    final result = await showDialog<_ListDetailsDraft>(
      context: context,
      builder: (context) {
        return _ListDetailsDialog(
          title: 'Edytuj listę',
          initialName: _listName,
          initialPlannedFor: _plannedFor,
          actionLabel: 'Zapisz',
        );
      },
    );

    if (result == null ||
        (result.name == _listName &&
            _sameDay(result.plannedFor, _plannedFor))) {
      return;
    }

    try {
      final updatedList = await widget.apiClient.updateList(
        widget.listId,
        name: result.name,
        plannedFor: result.plannedFor,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _didMutateList = true;
        _listName = updatedList.name;
        _plannedFor = updatedList.plannedFor;
        _lastWhatsAppDraft = _WhatsAppDraft.updatedList(updatedList.name);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zapisano zmiany listy.')),
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
            content: Text('Nie udało się zapisać listy: ${error.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _listName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (_plannedFor != null)
                Text(
                  'Data: ${_formatDate(_plannedFor!)}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _canNotifyOnWhatsApp ? _notifyOnWhatsApp : null,
              icon: _isLaunchingWhatsApp
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chat_outlined),
              tooltip: 'Powiadom przez WhatsApp',
            ),
            IconButton(
              onPressed: () => _reloadItems(),
              icon: const Icon(Icons.refresh),
              tooltip: 'Odśwież',
            ),
            PopupMenuButton<_ListAction>(
              onSelected: (action) {
                if (action == _ListAction.share) {
                  _shareList();
                } else if (action == _ListAction.rename) {
                  _editList();
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
                    child: Text('Edytuj listę'),
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
            await _reloadListDetail(silent: true);
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

  Future<void> _onIncrementRequested(ShoppingListItem item) async {
    if (_isItemPending(item.id)) {
      return;
    }

    await _changeQuantity(item, 1);
  }

  Future<void> _onEditRequested(ShoppingListItem item) async {
    if (_isItemPending(item.id)) {
      return;
    }

    await _editItem(item);
  }

  String _itemLabel(ShoppingListItem item) {
    if (item.quantity <= 1) {
      return item.name;
    }

    return '${item.name} (${item.quantity})';
  }

  Widget _buildItemTile(ShoppingListItem item) {
    final isPending = _isItemPending(item.id);
    final iconOption = itemIconOptionForKey(item.iconKey);

    return Dismissible(
      key: ValueKey<String>(item.id),
      direction:
          isPending ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      confirmDismiss: (_) async {
        await _deleteItem(item, confirm: false);
        return false;
      },
      child: Card(
        child: ListTile(
          onTap: isPending ? null : () => _onIncrementRequested(item),
          onLongPress: isPending ? null : () => _onEditRequested(item),
          leading: Checkbox(
            value: item.isChecked,
            onChanged: isPending
                ? null
                : (checked) => _onToggleRequested(item, checked),
          ),
          title: Text(
            _itemLabel(item),
            style: TextStyle(
              decoration: item.isChecked
                  ? TextDecoration.lineThrough
                  : TextDecoration.none,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: isPending ? null : () => _onEditRequested(item),
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edytuj produkt',
              ),
              Tooltip(
                message: iconOption.label,
                child: buildItemIconBadge(iconOption),
              ),
            ],
          ),
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

  bool get _canNotifyOnWhatsApp =>
      !_isLaunchingWhatsApp && _selectedWhatsAppContact != null;

  ListMember? get _selectedWhatsAppContact {
    for (final member in _sharing?.memberContacts ?? const <ListMember>[]) {
      if (member.user.whatsappEligible &&
          (member.user.phoneNumber?.trim().isNotEmpty ?? false)) {
        return member;
      }
    }

    return null;
  }

  String _describeDraft(ItemDraft draft) {
    return _buildItemDescription(
      name: draft.name,
      quantity: draft.quantity,
      comment: draft.comment,
    );
  }

  String _describeItem(ShoppingListItem item) {
    return _buildItemDescription(
      name: item.name,
      quantity: item.quantity,
      comment: item.comment,
    );
  }

  String _buildItemDescription({
    required String name,
    required int quantity,
    required String? comment,
  }) {
    final quantityLabel = quantity > 1 ? '$name ($quantity)' : name;
    final trimmedComment = comment?.trim();

    if (trimmedComment == null || trimmedComment.isEmpty) {
      return quantityLabel;
    }

    return '$quantityLabel, $trimmedComment';
  }

  Future<void> _notifyOnWhatsApp() async {
    final member = _selectedWhatsAppContact;
    if (member == null) {
      return;
    }

    final normalizedPhoneNumber = member.user.phoneNumber?.replaceAll(
      RegExp(r'\D'),
      '',
    );
    if (normalizedPhoneNumber == null || normalizedPhoneNumber.isEmpty) {
      return;
    }

    final message = (_lastWhatsAppDraft ?? _WhatsAppDraft.generic()).toMessage(
      listName: _listName,
      recipientName: member.user.displayName,
    );
    final uri = Uri(
      scheme: 'https',
      host: 'wa.me',
      path: '/$normalizedPhoneNumber',
      queryParameters: <String, String>{'text': message},
    );

    setState(() {
      _isLaunchingWhatsApp = true;
    });

    try {
      final launch = widget.urlLauncher ??
          (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
      final didLaunch = await launch(uri);

      if (!didLaunch && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nie udało się otworzyć WhatsApp. Sprawdź, czy aplikacja jest zainstalowana.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nie udało się otworzyć WhatsApp. Sprawdź, czy aplikacja jest zainstalowana.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLaunchingWhatsApp = false;
        });
      }
    }
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
      iconKey: draft.iconKey,
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
          children: _suggestions.map(
            (suggestion) {
              final iconOption = itemIconOptionForKey(suggestion.iconKey);
              return ActionChip(
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.6),
                avatar: Tooltip(
                  message: iconOption.label,
                  child: buildItemIconBadge(iconOption, size: 24),
                ),
                label: Text(
                  suggestion.comment == null || suggestion.comment!.isEmpty
                      ? suggestion.name
                      : '${suggestion.name} • ${suggestion.comment}',
                ),
                onPressed: () => _addSuggestion(suggestion),
              );
            },
          ).toList(growable: false),
        ),
      ],
    );
  }
}

enum _ListAction { share, rename }

enum _WhatsAppDraftKind { generic, added, updated, removed, updatedList }

class _WhatsAppDraft {
  const _WhatsAppDraft._(this.kind, this.subject);

  const _WhatsAppDraft.generic() : this._(_WhatsAppDraftKind.generic, null);

  const _WhatsAppDraft.added(String subject)
      : this._(_WhatsAppDraftKind.added, subject);

  const _WhatsAppDraft.updated(String subject)
      : this._(_WhatsAppDraftKind.updated, subject);

  const _WhatsAppDraft.removed(String subject)
      : this._(_WhatsAppDraftKind.removed, subject);

  const _WhatsAppDraft.updatedList(String listName)
      : this._(_WhatsAppDraftKind.updatedList, listName);

  final _WhatsAppDraftKind kind;
  final String? subject;

  String toMessage({
    required String listName,
    required String recipientName,
  }) {
    switch (kind) {
      case _WhatsAppDraftKind.added:
        return 'Hej $recipientName, dodalem do listy "$listName": $subject. Zerknij prosze.';
      case _WhatsAppDraftKind.updated:
        return 'Hej $recipientName, zaktualizowalem na liscie "$listName": $subject. Zerknij prosze.';
      case _WhatsAppDraftKind.removed:
        return 'Hej $recipientName, usunalem z listy "$listName": $subject. Zerknij prosze.';
      case _WhatsAppDraftKind.updatedList:
        return 'Hej $recipientName, zaktualizowalem szczegoly listy "$subject". Zerknij prosze.';
      case _WhatsAppDraftKind.generic:
        return 'Hej $recipientName, dodalem wazna aktualizacje do listy "$listName". Zerknij prosze.';
    }
  }
}

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
  const _ItemEditorDialog({
    this.initialItem,
    required this.suggestions,
  });

  final ShoppingListItem? initialItem;
  final List<ItemSuggestion> suggestions;

  @override
  State<_ItemEditorDialog> createState() => _ItemEditorDialogState();
}

class _ItemEditorDialogState extends State<_ItemEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late bool _isChecked;
  late final TextEditingController _commentController;
  late int _quantity;
  late String _iconKey;
  bool _iconKeyWasManuallySelected = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialItem?.name ?? '',
    );
    _commentController = TextEditingController(
      text: widget.initialItem?.comment ?? '',
    );
    _nameController.addListener(_maybeSyncSuggestedIcon);
    _commentController.addListener(_maybeSyncSuggestedIcon);
    _isChecked = widget.initialItem?.isChecked ?? false;
    _quantity = widget.initialItem?.quantity ?? 1;
    _iconKey = widget.initialItem?.iconKey ?? defaultItemIconKey;
  }

  @override
  void dispose() {
    _nameController.removeListener(_maybeSyncSuggestedIcon);
    _commentController.removeListener(_maybeSyncSuggestedIcon);
    _nameController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _maybeSyncSuggestedIcon() {
    if (_iconKeyWasManuallySelected) {
      return;
    }

    final nextIconKey = _suggestedIconKeyForProduct(
          suggestions: widget.suggestions,
          name: _nameController.text,
          comment: _commentController.text,
        ) ??
        defaultItemIconKey;

    if (nextIconKey == _iconKey) {
      return;
    }

    setState(() {
      _iconKey = nextIconKey;
    });
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    Navigator.of(context).pop(
      ItemDraft(
        name: _nameController.text.trim(),
        comment: _normalizedOptionalText(_commentController.text),
        quantity: _quantity,
        isChecked: _isChecked,
        iconKey: _iconKey,
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

  Future<void> _pickIcon() async {
    final selectedKey = await showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Wybierz ikonę kategorii'),
          children: [
            for (final option in itemIconOptions)
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(option.key),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      buildItemIconBadge(option, size: 28),
                      const SizedBox(width: 12),
                      Expanded(child: Text(option.label)),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );

    if (selectedKey == null) {
      return;
    }

    setState(() {
      _iconKey = selectedKey;
      _iconKeyWasManuallySelected = true;
    });
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
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Ilość'),
                  const Spacer(),
                  IconButton(
                    onPressed: _quantity > 1
                        ? () {
                            setState(() {
                              _quantity -= 1;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: 'Zmniejsz ilość',
                  ),
                  Text(
                    '$_quantity',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _quantity += 1;
                      });
                    },
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Zwiększ ilość',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Ikona kategorii',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickIcon,
                icon: buildItemIconBadge(itemIconOptionForKey(_iconKey),
                    size: 24),
                label: Text(itemIconOptionForKey(_iconKey).label),
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

class _ListDetailsDraft {
  const _ListDetailsDraft({
    required this.name,
    required this.plannedFor,
  });

  final String name;
  final DateTime? plannedFor;
}

class _ListDetailsDialog extends StatefulWidget {
  const _ListDetailsDialog({
    required this.title,
    required this.initialName,
    required this.actionLabel,
    this.initialPlannedFor,
  });

  final String title;
  final String initialName;
  final String actionLabel;
  final DateTime? initialPlannedFor;

  @override
  State<_ListDetailsDialog> createState() => _ListDetailsDialogState();
}

class _ListDetailsDialogState extends State<_ListDetailsDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  DateTime? _plannedFor;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    _plannedFor = widget.initialPlannedFor;
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

    Navigator.of(context).pop(
      _ListDetailsDraft(
        name: _controller.text.trim(),
        plannedFor: _plannedFor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
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
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Dodaj datę do nazwy'),
              subtitle: _plannedFor == null
                  ? null
                  : Text('Dzisiejsza data: ${_formatDate(_plannedFor!)}'),
              value: _plannedFor != null,
              onChanged: (enabled) {
                setState(() {
                  if (enabled) {
                    final now = DateTime.now();
                    _plannedFor = DateTime(now.year, now.month, now.day);
                  } else {
                    _plannedFor = null;
                  }
                });
              },
            ),
          ],
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

String _formatDate(DateTime value) {
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

bool _sameDay(DateTime? left, DateTime? right) {
  if (left == null || right == null) {
    return left == right;
  }

  final leftLocal = left.toLocal();
  final rightLocal = right.toLocal();
  return leftLocal.year == rightLocal.year &&
      leftLocal.month == rightLocal.month &&
      leftLocal.day == rightLocal.day;
}
