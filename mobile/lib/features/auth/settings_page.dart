import 'package:flutter/material.dart';

import 'auth_profile_store.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    this.savedProfile,
    this.onResetLocalData,
    super.key,
  });

  final SavedAuthProfile? savedProfile;
  final Future<void> Function()? onResetLocalData;

  Future<void> _confirmAndReset(BuildContext context) async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset saved auth data'),
          content: const Text(
            'This clears the remembered backend URL, email, and saved session from this device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (shouldReset != true || onResetLocalData == null) {
      return;
    }

    await onResetLocalData!();

    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
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
                    'Advanced configuration lives here.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  if (savedProfile != null) ...[
                    Text(
                      'Saved auth data',
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('Backend: ${savedProfile!.baseUrl}'),
                    const SizedBox(height: 4),
                    Text('Email: ${savedProfile!.email}'),
                    const SizedBox(height: 16),
                  ],
                  OutlinedButton(
                    onPressed: onResetLocalData == null
                        ? null
                        : () => _confirmAndReset(context),
                    child: const Text('Reset saved auth data'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
