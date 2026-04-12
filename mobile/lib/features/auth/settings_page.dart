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
          title: const Text('Wyczyść zapisane dane'),
          content: const Text(
            'To usunie z tego urządzenia zapamiętany adres backendu, email i zapisaną sesję.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Anuluj'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Wyczyść'),
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
        title: const Text('Ustawienia'),
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
                    'Ustawienia aplikacji',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tutaj znajdziesz ustawienia techniczne aplikacji.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  if (savedProfile != null) ...[
                    Text(
                      'Zapisane dane logowania',
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
                    child: const Text('Wyczyść zapisane dane'),
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
