import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/collection_sync.dart';

class ListDetailPage extends StatefulWidget {
  const ListDetailPage({
    required this.apiClient,
    required this.listId,
    this.listName,
    this.onUnauthorized,
    super.key,
  });

  final ApiClient apiClient;
  final String listId;
  final String? listName;
  final Future<void> Function()? onUnauthorized;

  @override
  State<ListDetailPage> createState() => _ListDetailPageState();
}

class _ListDetailPageState extends State<ListDetailPage> {
  final List<ShoppingListItem> _items = <ShoppingListItem>[];
  final Set<String> _pendingItemIds = <String>{};
  final Map<String, _PendingItemMutation> _pendingItemMutations =
      <String, _PendingItemMutation>{};

  bool _isLoading = true;
  bool _isSharing = false;
  bool _didMutateItems = false;
  String? _errorMessage;
  int _temporaryItemCounter = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _reloadItems();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        _reloadItems(silent: true);
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
          SnackBar(content: Text('Could not refresh items: $message')),
        );
      }
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

    final temporaryId = _nextTemporaryItemId();
    final optimisticItem = _buildOptimisticItem(
      id: temporaryId,
      draft: draft,
      sortOrder: _nextSortOrder(),
    );

    setState(() {
      _didMutateItems = true;
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
        SnackBar(content: Text('Could not add item: ${error.message}')),
      );
    }
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
      quantity: draft.quantity,
      unit: draft.unit,
      isChecked: draft.isChecked,
    );

    setState(() {
      _didMutateItems = true;
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
        SnackBar(content: Text('Could not save item: ${error.message}')),
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
      _didMutateItems = true;
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
        SnackBar(content: Text('Could not update item: ${error.message}')),
      );
    }
  }

  Future<void> _deleteItem(ShoppingListItem item) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete item'),
          content: Text('Delete "${item.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
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
      _didMutateItems = true;
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
        SnackBar(content: Text('Could not delete item: ${error.message}')),
      );
    }
  }

  Future<void> _shareList() async {
    if (_isSharing) {
      return;
    }

    final email = await showDialog<String>(
      context: context,
      builder: (context) {
        return const _ShareListDialog();
      },
    );

    if (email == null) {
      return;
    }

    setState(() {
      _isSharing = true;
    });

    try {
      final member = await widget.apiClient.shareList(
        listId: widget.listId,
        email: email,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Shared with ${member.user.email}.')),
      );
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

  @override
  Widget build(BuildContext context) {
    final title = widget.listName ?? 'List ${widget.listId}';

    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        Navigator.of(context).pop(_didMutateItems);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: () => Navigator.of(context).pop(_didMutateItems),
          ),
          title: Text(title),
          bottom: widget.listName == null
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(24),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      widget.listId,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
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
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<_ListAction>(
                  value: _ListAction.share,
                  enabled: !_isSharing,
                  child: const Text('Share list'),
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
          onRefresh: () => _reloadItems(silent: true),
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
          onChanged: isPending
              ? null
              : (checked) => _onToggleRequested(item, checked),
        ),
        title: Text(
          item.name,
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
    _items.sort((left, right) {
      final byOrder = left.sortOrder.compareTo(right.sortOrder);
      if (byOrder != 0) {
        return byOrder;
      }

      return left.createdAt.compareTo(right.createdAt);
    });
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

    merged.sort((left, right) {
      final byOrder = left.sortOrder.compareTo(right.sortOrder);
      if (byOrder != 0) {
        return byOrder;
      }

      return left.createdAt.compareTo(right.createdAt);
    });

    return merged;
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
      quantity: draft.quantity,
      unit: draft.unit,
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
                  'Could not load items',
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
                  child: const Text('Retry'),
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
        children: const [
          SizedBox(height: 160),
          Center(child: Text('No items yet. Add the first one.')),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: _items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _items[index];

        return _buildItemTile(item);
      },
    );
  }

  Widget? _buildSubtitle(ShoppingListItem item) {
    final details = <String>[];

    if (item.quantity != null && item.quantity!.isNotEmpty) {
      details.add(item.quantity!);
    }

    if (item.unit != null && item.unit!.isNotEmpty) {
      details.add(item.unit!);
    }

    if (details.isEmpty) {
      return null;
    }

    return Text(details.join(' '));
  }
}

enum _ListAction { share }

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
  late final TextEditingController _quantityController;
  late final TextEditingController _unitController;
  late bool _isChecked;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialItem?.name ?? '',
    );
    _quantityController = TextEditingController(
      text: widget.initialItem?.quantity ?? '',
    );
    _unitController = TextEditingController(
      text: widget.initialItem?.unit ?? '',
    );
    _isChecked = widget.initialItem?.isChecked ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    Navigator.of(context).pop(
      ItemDraft(
        name: _nameController.text.trim(),
        quantity: _normalizedOptionalText(_quantityController.text),
        unit: _normalizedOptionalText(_unitController.text),
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
      title: Text(isEditing ? 'Edit item' : 'Add item'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final trimmed = value?.trim() ?? '';

                  if (trimmed.isEmpty) {
                    return 'Name is required';
                  }

                  return null;
                },
              ),
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(labelText: 'Quantity'),
                textInputAction: TextInputAction.next,
              ),
              TextFormField(
                controller: _unitController,
                decoration: const InputDecoration(labelText: 'Unit'),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Checked'),
                value: _isChecked,
                onChanged: (value) {
                  setState(() {
                    _isChecked = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class _ShareListDialog extends StatefulWidget {
  const _ShareListDialog();

  @override
  State<_ShareListDialog> createState() => _ShareListDialogState();
}

class _ShareListDialogState extends State<_ShareListDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    Navigator.of(context).pop(_emailController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Share list'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _emailController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'User email',
            hintText: 'second-user@example.com',
          ),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          validator: (value) {
            final trimmed = value?.trim() ?? '';

            if (trimmed.isEmpty) {
              return 'Email is required';
            }

            final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

            if (!emailPattern.hasMatch(trimmed)) {
              return 'Enter a valid email address';
            }

            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Share')),
      ],
    );
  }
}
