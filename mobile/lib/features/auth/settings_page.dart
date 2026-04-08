import 'package:flutter/material.dart';

import '../../core/theme/theme_mode_menu.dart';

typedef BackendUrlChanged = Future<void> Function(String baseUrl);

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    required this.currentBackendUrl,
    required this.onBackendUrlChanged,
    required this.onLogout,
    required this.themeMode,
    required this.onThemeModeChanged,
    super.key,
  });

  final String currentBackendUrl;
  final BackendUrlChanged onBackendUrlChanged;
  final Future<void> Function() onLogout;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  Future<void> _editBackendUrl(BuildContext context) async {
    final updatedBaseUrl = await showDialog<String>(
      context: context,
      builder: (context) {
        return _BackendUrlDialog(initialValue: currentBackendUrl);
      },
    );

    if (updatedBaseUrl == null) {
      return;
    }

    await onBackendUrlChanged(updatedBaseUrl);

    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

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
                    'Advanced',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Backend URL',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(currentBackendUrl),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () => _editBackendUrl(context),
                    child: const Text('Change backend URL'),
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

class _BackendUrlDialog extends StatefulWidget {
  const _BackendUrlDialog({
    required this.initialValue,
  });

  final String initialValue;

  @override
  State<_BackendUrlDialog> createState() => _BackendUrlDialogState();
}

class _BackendUrlDialogState extends State<_BackendUrlDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Backend URL'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'API base URL',
            hintText: 'http://100.113.187.63',
          ),
          validator: (value) {
            final trimmed = value?.trim() ?? '';

            if (trimmed.isEmpty) {
              return 'API base URL is required';
            }

            final uri = Uri.tryParse(trimmed);

            if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
              return 'Enter a valid URL';
            }

            return null;
          },
          onFieldSubmitted: (_) => _submit(),
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
