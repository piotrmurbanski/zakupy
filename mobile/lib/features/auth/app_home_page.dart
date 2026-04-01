import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../lists/list_detail_page.dart';
import 'auth_repository.dart';
import 'auth_session_store.dart';

class AppHomePage extends StatefulWidget {
  const AppHomePage(
      {required this.session,
      required this.authRepository,
      required this.onLogout,
      super.key});

  final StoredAuthSession session;
  final AuthRepository authRepository;
  final Future<void> Function() onLogout;

  @override
  State<AppHomePage> createState() => _AppHomePageState();
}

class _AppHomePageState extends State<AppHomePage> {
  final List<ShoppingListSummary> _lists = <ShoppingListSummary>[];

  bool _isLoggingOut = false;
  bool _isLoading = true;
  bool _isUpdating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  Future<void> _logout() async {
    setState(() {
      _isLoggingOut = true;
    });

    try {
      await widget.onLogout();
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  ApiClient get _apiClient {
    return widget.authRepository.buildAuthenticatedClient(widget.session);
  }

  Future<void> _loadLists({bool silent = false}) async {
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
    }
  }

  Future<void> _createList() async {
    final name = await _showTextPrompt(
      title: 'Create list',
      label: 'List name',
      actionLabel: 'Create',
    );

    if (name == null) {
      return;
    }

    await _runMutation(() async {
      await _apiClient.createList(name);
      await _loadLists(silent: true);
    });
  }

  Future<void> _shareList(ShoppingListSummary list) async {
    final email = await _showTextPrompt(
      title: 'Share list',
      label: 'User email',
      actionLabel: 'Share',
      keyboardType: TextInputType.emailAddress,
    );

    if (email == null) {
      return;
    }

    await _runMutation(() async {
      final member = await _apiClient.shareList(
        listId: list.id,
        email: email,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Shared with ${member.user.email}.')),
      );
    });
  }

  Future<void> _editBackendUrl() async {
    final updatedBaseUrl = await _showTextPrompt(
      title: 'Backend URL',
      label: 'API base URL',
      actionLabel: 'Save',
      initialValue: widget.session.baseUrl,
      keyboardType: TextInputType.url,
    );

    if (updatedBaseUrl == null || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Log out and sign back in to switch the saved backend URL.'),
      ),
    );
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
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ListDetailPage(
          apiClient: _apiClient,
          listId: list.id,
          listName: list.name,
          onUnauthorized: widget.onLogout,
        ),
      ),
    );

    await _loadLists(silent: true);
  }

  Future<String?> _showTextPrompt({
    required String title,
    required String label,
    required String actionLabel,
    String initialValue = '',
    TextInputType? keyboardType,
  }) {
    final controller = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              autofocus: true,
              decoration: InputDecoration(labelText: label),
              validator: (value) {
                if ((value?.trim() ?? '').isEmpty) {
                  return '$label is required';
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
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) {
                  return;
                }

                Navigator.of(context).pop(controller.text.trim());
              },
              child: Text(actionLabel),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your lists'),
        actions: [
          IconButton(
            onPressed: _isUpdating ? null : () => _loadLists(),
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'backend') {
                await _editBackendUrl();
              } else if (value == 'logout') {
                await _logout();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'backend',
                child: Text('Backend URL'),
              ),
              PopupMenuItem<String>(
                value: 'logout',
                child: Text('Log out'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUpdating ? null : _createList,
        icon: const Icon(Icons.add),
        label: const Text('New list'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadLists(silent: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.session.session.user.displayName,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(widget.session.session.user.email),
                    const SizedBox(height: 12),
                    Text(widget.session.baseUrl, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonal(
                          onPressed: _editBackendUrl,
                          child: const Text('Change backend'),
                        ),
                        const Chip(
                          label: Text('Session saved on this device'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
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
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else if (_lists.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 32),
                child: Center(
                  child: Text('No lists yet. Create the first one to get started.'),
                ),
              )
            else
              ..._lists.map(
                (list) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: ListTile(
                      onTap: () => _openList(list),
                      title: Text(list.name),
                      subtitle: Text(
                        list.isOwnedBy(widget.session.session.user.id)
                            ? 'Owner'
                            : 'Shared with you',
                      ),
                      trailing: list.isOwnedBy(widget.session.session.user.id)
                          ? IconButton(
                              tooltip: 'Share list',
                              onPressed: _isUpdating ? null : () => _shareList(list),
                              icon: const Icon(Icons.person_add_alt_1_outlined),
                            )
                          : const Icon(Icons.chevron_right),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
