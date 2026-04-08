import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class ShareEmailHistoryStore {
  Future<List<String>> readRecentEmails();
  Future<void> rememberEmail(String email);
}

class SecureShareEmailHistoryStore implements ShareEmailHistoryStore {
  SecureShareEmailHistoryStore({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const String _key = 'zakupy_share_emails_v1';
  static const int _maxEmails = 8;

  final FlutterSecureStorage _storage;

  @override
  Future<List<String>> readRecentEmails() async {
    final value = await _storage.read(key: _key);

    if (value == null || value.trim().isEmpty) {
      return const <String>[];
    }

    final decoded = jsonDecode(value);

    if (decoded is! Map) {
      return const <String>[];
    }

    final map = Map<String, dynamic>.from(decoded);
    final emails = map['emails'];

    if (emails is! List) {
      return const <String>[];
    }

    final normalized = emails
        .whereType<String>()
        .map((email) => email.trim().toLowerCase())
        .where((email) => email.isNotEmpty)
        .toList(growable: false);

    final unique = <String>[];
    for (final email in normalized) {
      if (!unique.contains(email)) {
        unique.add(email);
      }
    }

    return unique;
  }

  @override
  Future<void> rememberEmail(String email) async {
    final normalized = _normalizeEmail(email);

    if (normalized == null) {
      return;
    }

    final current = await readRecentEmails();
    final next = <String>[
      normalized,
      ...current.where((entry) => entry != normalized),
    ].take(_maxEmails).toList(growable: false);

    await _storage.write(
      key: _key,
      value: jsonEncode({'emails': next}),
    );
  }

  String? _normalizeEmail(String email) {
    final normalized = email.trim().toLowerCase();

    if (normalized.isEmpty) {
      return null;
    }

    return normalized;
  }
}

class InMemoryShareEmailHistoryStore implements ShareEmailHistoryStore {
  InMemoryShareEmailHistoryStore([List<String>? seed]) {
    _emails = <String>[];

    for (final email in seed ?? const <String>[]) {
      final normalized = email.trim().toLowerCase();

      if (normalized.isEmpty || _emails.contains(normalized)) {
        continue;
      }

      _emails.add(normalized);
    }
  }

  late List<String> _emails;

  @override
  Future<List<String>> readRecentEmails() async {
    return List<String>.unmodifiable(_emails);
  }

  @override
  Future<void> rememberEmail(String email) async {
    final normalized = email.trim().toLowerCase();

    if (normalized.isEmpty) {
      return;
    }

    _emails = <String>[
      normalized,
      ..._emails.where((entry) => entry != normalized),
    ].take(SecureShareEmailHistoryStore._maxEmails).toList(growable: false);
  }
}

Future<String?> showShareListDialog(
  BuildContext context, {
  required ShareEmailHistoryStore historyStore,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) {
      return _ShareListDialog(historyStore: historyStore);
    },
  );
}

class _ShareListDialog extends StatefulWidget {
  const _ShareListDialog({
    required this.historyStore,
  });

  final ShareEmailHistoryStore historyStore;

  @override
  State<_ShareListDialog> createState() => _ShareListDialogState();
}

class _ShareListDialogState extends State<_ShareListDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  List<String> _recentEmails = const <String>[];
  bool _isLoadingSuggestions = true;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    final emails = await widget.historyStore.readRecentEmails();

    if (!mounted) {
      return;
    }

    setState(() {
      _recentEmails = emails;
      _isLoadingSuggestions = false;
    });
  }

  void _fillEmail(String email) {
    setState(() {
      _emailController.text = email;
      _emailController.selection = TextSelection.collapsed(
        offset: _emailController.text.length,
      );
    });
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
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
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
              const SizedBox(height: 16),
              if (_isLoadingSuggestions)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              else if (_recentEmails.isNotEmpty) ...[
                Text(
                  'Recent emails',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _recentEmails
                      .map(
                        (email) => ActionChip(
                          label: Text(email),
                          onPressed: () => _fillEmail(email),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
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
          child: const Text('Share'),
        ),
      ],
    );
  }
}
