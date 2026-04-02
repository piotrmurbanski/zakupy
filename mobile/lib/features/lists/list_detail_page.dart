import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';

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

  bool _isLoading = true;
  bool _isSharing = false;
  String? _errorMessage;
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
        _items
          ..clear()
          ..addAll(items);
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

      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
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

    final maxSortOrder = _items.isEmpty
        ? -1
        : _items
            .map((item) => item.sortOrder)
            .reduce((current, next) => current > next ? current : next);
    final temporaryId = '_tmp_${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now();
    final temporaryItem = ShoppingListItem(
      id: temporaryId,
      listId: widget.listId,
      name: draft.name,
      quantity: draft.quantity,
      unit: draft.unit,
      isChecked: draft.isChecked,
      sortOrder: maxSortOrder + 1,
      createdByUserId: '',
      createdAt: now,
      updatedAt: now,
    );

    if (mounted) {
      setState(() {
        _items.add(temporaryItem);
      });
    }

    try {
      await widget.apiClient.createItem(widget.listId, draft);
      await _reloadItems(silent: true);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _items.removeWhere((item) => item.id == temporaryId);
        });
      }

      if (error.isUnauthorized && widget.onUnauthorized != null) {
        await widget.onUnauthorized!();
        return;
      }

      if (!mounted) {
        return;
      }
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

    final previousItem = item;
    final optimisticItem = ShoppingListItem(
      id: item.id,
      listId: item.listId,
      name: draft.name,
      quantity: draft.quantity,
      unit: draft.unit,
      isChecked: draft.isChecked,
      sortOrder: item.sortOrder,
      createdByUserId: item.createdByUserId,
      createdAt: item.createdAt,
      updatedAt: DateTime.now(),
    );
    if (mounted) {
      final index = _items.indexWhere((current) => current.id == item.id);
      if (index >= 0) {
        setState(() {
          _items[index] = optimisticItem;
        });
      }
    }

    try {
      await widget.apiClient.updateItem(widget.listId, item.id, draft);
      await _reloadItems(silent: true);
    } on ApiException catch (error) {
      if (mounted) {
        final index = _items.indexWhere((current) => current.id == item.id);
        if (index >= 0) {
          setState(() {
            _items[index] = previousItem;
          });
        }
      }

      if (error.isUnauthorized && widget.onUnauthorized != null) {
        await widget.onUnauthorized!();
        return;
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save item: ${error.message}')),
      );
    }
  }

  Future<void> _toggleItem(ShoppingListItem item, bool? checked) async {
    if (checked == null) {
      return;
    }

    final previousItem = item;
    final optimisticItem = ShoppingListItem(
      id: item.id,
      listId: item.listId,
      name: item.name,
      quantity: item.quantity,
      unit: item.unit,
      isChecked: checked,
      sortOrder: item.sortOrder,
      createdByUserId: item.createdByUserId,
      createdAt: item.createdAt,
      updatedAt: DateTime.now(),
    );
    if (mounted) {
      final index = _items.indexWhere((current) => current.id == item.id);
      if (index >= 0) {
        setState(() {
          _items[index] = optimisticItem;
        });
      }
    }

    try {
      await widget.apiClient.updateItem(
        widget.listId,
        item.id,
        item.toDraft().copyWith(isChecked: checked),
      );
      await _reloadItems(silent: true);
    } on ApiException catch (error) {
      if (mounted) {
        final index = _items.indexWhere((current) => current.id == item.id);
        if (index >= 0) {
          setState(() {
            _items[index] = previousItem;
          });
        }
      }

      if (error.isUnauthorized && widget.onUnauthorized != null) {
        await widget.onUnauthorized!();
        return;
      }

      if (!mounted) {
        return;
      }

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

    final previousItems = List<ShoppingListItem>.from(_items);
    if (mounted) {
      setState(() {
        _items.removeWhere((current) => current.id == item.id);
      });
    }

    try {
      await widget.apiClient.deleteItem(widget.listId, item.id);
      await _reloadItems(silent: true);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _items
            ..clear()
            ..addAll(previousItems);
        });
      }

      if (error.isUnauthorized && widget.onUnauthorized != null) {
        await widget.onUnauthorized!();
        return;
      }

      if (!mounted) {
        return;
      }

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
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

    return Scaffold(
      appBar: AppBar(
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
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 240),
          Center(
            child: CircularProgressIndicator(),
          ),
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
          Center(
            child: Text('No items yet. Add the first one.'),
          ),
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

        return Card(
          child: ListTile(
            leading: Checkbox(
              value: item.isChecked,
              onChanged: (checked) => _toggleItem(item, checked),
            ),
            title: Text(
              item.name,
              style: TextStyle(
                decoration:
                    item.isChecked ? TextDecoration.lineThrough : TextDecoration.none,
              ),
            ),
            subtitle: _buildSubtitle(item),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _editItem(item),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  onPressed: () => _deleteItem(item),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        );
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

enum _ListAction {
  share,
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
    _nameController = TextEditingController(text: widget.initialItem?.name ?? '');
    _quantityController =
        TextEditingController(text: widget.initialItem?.quantity ?? '');
    _unitController = TextEditingController(text: widget.initialItem?.unit ?? '');
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
        FilledButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
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
        FilledButton(
          onPressed: _submit,
          child: const Text('Share'),
        ),
      ],
    );
  }
}
