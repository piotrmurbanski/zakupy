import 'package:flutter/material.dart';

import '../lists/list_detail_page.dart';
import 'auth_repository.dart';
import 'session_store.dart';

class AppHomePage extends StatefulWidget {
  const AppHomePage(
      {required this.session,
      required this.authRepository,
      required this.onLogout,
      super.key});

  final AppSession session;
  final AuthRepository authRepository;
  final Future<void> Function() onLogout;

  @override
  State<AppHomePage> createState() => _AppHomePageState();
}

class _AppHomePageState extends State<AppHomePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _listIdController;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _listIdController = TextEditingController();
  }

  @override
  void dispose() {
    _listIdController.dispose();
    super.dispose();
  }

  Future<void> _openList() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final apiClient =
        widget.authRepository.buildAuthenticatedClient(widget.session);

    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (context) => ListDetailPage(
            apiClient: apiClient, listId: _listIdController.text.trim())));
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
        appBar: AppBar(title: const Text('Zakupy'), actions: [
          TextButton(
              onPressed: _isLoggingOut ? null : _logout,
              child: Text('Log out',
                  style: TextStyle(color: theme.colorScheme.primary)))
        ]),
        body: Center(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Card(
                              child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            'Signed in as ${widget.session.user.displayName}',
                                            style: theme.textTheme.titleLarge),
                                        const SizedBox(height: 8),
                                        Text(widget.session.user.email),
                                        const SizedBox(height: 4),
                                        Text(widget.session.baseUrl,
                                            style: theme.textTheme.bodySmall)
                                      ]))),
                          const SizedBox(height: 16),
                          Card(
                              child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Form(
                                      key: _formKey,
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Text('Open a shopping list',
                                                style: theme
                                                    .textTheme.titleMedium),
                                            const SizedBox(height: 8),
                                            Text(
                                                'The broader lists dashboard is still ahead of us, so this screen keeps the existing direct list opener for now.',
                                                style:
                                                    theme.textTheme.bodyMedium),
                                            const SizedBox(height: 16),
                                            TextFormField(
                                                controller: _listIdController,
                                                decoration:
                                                    const InputDecoration(
                                                        labelText: 'List ID'),
                                                validator: (value) {
                                                  final trimmed =
                                                      value?.trim() ?? '';

                                                  if (trimmed.isEmpty) {
                                                    return 'List ID is required';
                                                  }

                                                  return null;
                                                }),
                                            const SizedBox(height: 16),
                                            FilledButton(
                                                onPressed: _openList,
                                                child: const Text('Open list'))
                                          ]))))
                        ])))));
  }
}
