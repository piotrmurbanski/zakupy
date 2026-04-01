import 'package:flutter/material.dart';

import '../lists/lists_overview_page.dart';
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
  bool _isLoggingOut = false;

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
    final apiClient = widget.authRepository.buildAuthenticatedClient(widget.session);

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
                                            'Signed in as ${widget.session.session.user.displayName}',
                                            style: theme.textTheme.titleLarge),
                                        const SizedBox(height: 8),
                                        Text(widget.session.session.user.email),
                                        const SizedBox(height: 4),
                                        Text(widget.session.baseUrl,
                                            style: theme.textTheme.bodySmall)
                                      ]))),
                          const SizedBox(height: 16),
                          Card(
                              child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text('Your shopping lists',
                                            style:
                                                theme.textTheme.titleMedium),
                                        const SizedBox(height: 8),
                                        Text(
                                            'Browse the lists available to your account and open any shared list from the overview.',
                                            style:
                                                theme.textTheme.bodyMedium),
                                        const SizedBox(height: 16),
                                        FilledButton(
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute<void>(
                                                  builder: (context) =>
                                                      ListsOverviewPage(
                                                    apiClient: apiClient,
                                                  ),
                                                ),
                                              );
                                            },
                                            child:
                                                const Text('Open my lists'))
                                      ]))))
                        ])))));
  }
}
