import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/collection_sync.dart';
import '../../core/theme/theme_mode_menu.dart';
import 'auth_profile_store.dart';
import '../lists/archived_lists_page.dart';
import '../lists/list_detail_page.dart';
import 'auth_repository.dart';
import 'auth_session_store.dart';
import 'settings_page.dart';

class AppHomePage extends StatefulWidget {
  const AppHomePage({
    required this.session,
    required this.authRepository,
    required this.onLogout,
    required this.onResetLocalData,
    required this.themeMode,
    required this.onThemeModeChanged,
    this.savedProfile,
    super.key,
  });

  final StoredAuthSession session;
  final AuthRepository authRepository;
  final Future<void> Function() onLogout;
  final Future<void> Function() onResetLocalData;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final SavedAuthProfile? savedProfile;

  @override
  State<AppHomePage> createState() => _AppHomePageState();
}

class _AppHomePageState extends State<AppHomePage> {
  final List<ShoppingListSummary> _lists = <ShoppingListSummary>[];
  Timer? _refreshTimer;

  bool _isLoading = true;
  bool _isUpdating = false;
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

  ApiClient get _apiClient {
    return widget.authRepository.buildAuthenticatedClient(widget.session);
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
      final lists = await _apiClient.fetchLists();

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
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await widget.onLogout();
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

  Future<void> _createList() async {
    final draft = await showDialog<_ListDraft>(
      context: context,
      builder: (context) => const _ListEditorDialog(
        title: 'Nowa lista',
        actionLabel: 'Dodaj',
      ),
    );

    if (draft == null) {
      return;
    }

    await _runMutation(() async {
      final createdList = await _apiClient.createList(
        name: draft.name,
        plannedFor: draft.plannedFor,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        upsertById(
          target: _lists,
          value: createdList,
          idOf: (list) => list.id,
        );
      });
    });
  }

  Future<void> _runMutation(Future<void> Function() action) async {
    setState(() {
      _isUpdating = true;
    });

    try {
      await action();
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await widget.onLogout();
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
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _openList(ShoppingListSummary list) async {
    final didMutate = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => ListDetailPage(
          apiClient: _apiClient,
          listId: list.id,
          listName: list.name,
          plannedFor: list.plannedFor,
          isArchived: list.isArchived,
          canManageList: list.ownerUserId == widget.session.session.user.id,
          onUnauthorized: widget.onLogout,
        ),
      ),
    );

    if (didMutate == true) {
      await _loadLists(silent: true);
    }
  }

  Future<void> _openArchivedLists() async {
    final didMutate = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => ArchivedListsPage(
          apiClient: _apiClient,
          currentUserId: widget.session.session.user.id,
          onUnauthorized: widget.onLogout,
        ),
      ),
    );

    if (didMutate == true) {
      await _loadLists(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Twoje listy'),
        actions: [
          IconButton(
            onPressed: _isUpdating ? null : () => _loadLists(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Odśwież',
          ),
          IconButton(
            onPressed: _openArchivedLists,
            icon: const Icon(Icons.archive_outlined),
            tooltip: 'Archiwum',
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => SettingsPage(
                    savedProfile: widget.savedProfile,
                    onResetLocalData: widget.onResetLocalData,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Ustawienia',
          ),
          ThemeModeMenuButton(
            currentThemeMode: widget.themeMode,
            onSelected: widget.onThemeModeChanged,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUpdating ? null : _createList,
        icon: const Icon(Icons.add),
        label: const Text('Nowa lista'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadLists(silent: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            if (_isLoading && _lists.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null && _lists.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 12),
                    Text(_errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => _loadLists(),
                      child: const Text('Spróbuj ponownie'),
                    ),
                  ],
                ),
              )
            else if (_lists.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 32),
                child: Center(
                  child: Text(
                    'Brak list. Dodaj pierwszą.',
                  ),
                ),
              )
            else
              ..._lists.map(
                (list) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildListCard(list),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildListCard(ShoppingListSummary list) {
    final canArchive = list.isOwnedBy(widget.session.session.user.id);
    final card = Card(
      child: ListTile(
        onTap: () => _openList(list),
        title: _ListTitle(name: list.name, plannedFor: list.plannedFor),
        subtitle: Text(
          list.isOwnedBy(widget.session.session.user.id)
              ? 'Właściciel'
              : 'Udostępniona Tobie',
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );

    if (!canArchive) {
      return card;
    }

    return Dismissible(
      key: ValueKey<String>('active-list-${list.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.archive_outlined,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
      confirmDismiss: (_) async {
        await _archiveList(list);
        return false;
      },
      child: card,
    );
  }

  Future<void> _archiveList(ShoppingListSummary list) async {
    await _runMutation(() async {
      final archivedList = await _apiClient.archiveList(list.id);

      if (!mounted) {
        return;
      }

      setState(() {
        removeById(target: _lists, id: list.id, idOf: (entry) => entry.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            archivedList.name.isEmpty
                ? 'Lista przeniesiona do archiwum.'
                : 'Lista ${archivedList.name} została przeniesiona do archiwum.',
          ),
        ),
      );
    });
  }
}

class _ListTitle extends StatelessWidget {
  const _ListTitle({
    required this.name,
    required this.plannedFor,
  });

  final String name;
  final DateTime? plannedFor;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 6,
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
              _formatDate(plannedFor!),
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
      ],
    );
  }

  static String _formatDate(DateTime value) {
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
}

class _ListDraft {
  const _ListDraft({
    required this.name,
    required this.plannedFor,
  });

  final String name;
  final DateTime? plannedFor;
}

class _ListEditorDialog extends StatefulWidget {
  const _ListEditorDialog({
    required this.title,
    required this.actionLabel,
  });

  final String title;
  final String actionLabel;

  @override
  State<_ListEditorDialog> createState() => _ListEditorDialogState();
}

class _ListEditorDialogState extends State<_ListEditorDialog> {
  late final TextEditingController _nameController;
  final _formKey = GlobalKey<FormState>();
  DateTime? _plannedFor;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _plannedFor = null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nazwa listy'),
              validator: (value) {
                if ((value?.trim() ?? '').isEmpty) {
                  return 'Nazwa listy jest wymagana';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Dodaj datę do nazwy'),
              subtitle: _plannedFor == null
                  ? null
                  : Text('Dzisiejsza data: ${_ListTitle._formatDate(_plannedFor!)}'),
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
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) {
              return;
            }

            Navigator.of(context).pop(
              _ListDraft(
                name: _nameController.text.trim(),
                plannedFor: _plannedFor,
              ),
            );
          },
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }
}
