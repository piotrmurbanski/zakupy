import 'package:flutter/material.dart';

import '../lists/list_overview_page.dart';
import 'auth_repository.dart';
import 'auth_session_store.dart';

class AppHomePage extends StatefulWidget {
  const AppHomePage({
    required this.session,
    required this.authRepository,
    required this.onLogout,
    super.key,
  });

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

    return ListOverviewPage(
      apiClient: widget.authRepository.buildAuthenticatedClient(widget.session),
      actions: [
        TextButton(
          onPressed: _isLoggingOut ? null : _logout,
          child: Text(
            'Log out',
            style: TextStyle(color: theme.colorScheme.primary),
          ),
        ),
      ],
      header: Card(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Signed in as ${widget.session.session.user.displayName}',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(widget.session.session.user.email),
              const SizedBox(height: 4),
              Text(
                widget.session.baseUrl,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
