import 'package:flutter/material.dart';

import '../../core/theme/theme_mode_menu.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    required this.onLogout,
    required this.themeMode,
    required this.onThemeModeChanged,
    super.key,
  });

  final Future<void> Function() onLogout;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          ThemeModeMenuButton(
            currentThemeMode: themeMode,
            onSelected: onThemeModeChanged,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App settings',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Advanced configuration will live here.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Log out'),
              subtitle: const Text('Clear the session from this device'),
              onTap: () async {
                await onLogout();
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
