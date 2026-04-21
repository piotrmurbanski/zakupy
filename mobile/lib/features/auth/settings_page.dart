import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_models.dart';
import 'auth_profile_store.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.currentUser,
    required this.onUpdatePhoneNumber,
    this.savedProfile,
    this.onResetLocalData,
    super.key,
  });

  final AuthUser currentUser;
  final Future<AuthUser> Function(String? phoneNumber) onUpdatePhoneNumber;
  final SavedAuthProfile? savedProfile;
  final Future<void> Function()? onResetLocalData;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _phoneController;
  late final FocusNode _phoneFocusNode;

  bool _isSaving = false;
  String? _errorMessage;
  String? _savedPhoneNumber;

  @override
  void initState() {
    super.initState();
    _savedPhoneNumber = widget.currentUser.phoneNumber;
    _phoneController = TextEditingController(text: _savedPhoneNumber ?? '');
    _phoneFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  bool get _hasSavedPhoneNumber => (_savedPhoneNumber ?? '').trim().isNotEmpty;

  String get _phoneButtonLabel =>
      _hasSavedPhoneNumber ? 'Zapisz zmiany' : 'Zapisz numer';

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

    if (shouldReset != true || widget.onResetLocalData == null) {
      return;
    }

    await widget.onResetLocalData!();

    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  String? _validatePhoneNumber(String rawValue) {
    final trimmed = rawValue.trim();

    if (trimmed.isEmpty) {
      return 'Wpisz numer telefonu albo użyj przycisku Usuń numer.';
    }

    final normalized = trimmed.replaceAll(RegExp(r'\s+'), '');
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(normalized)) {
      return 'Podaj numer w formacie międzynarodowym, np. +48123123123.';
    }

    return null;
  }

  Future<void> _savePhoneNumber() async {
    final validationMessage = _validatePhoneNumber(_phoneController.text);
    if (validationMessage != null) {
      setState(() {
        _errorMessage = validationMessage;
      });
      _phoneFocusNode.requestFocus();
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final updatedUser = await widget.onUpdatePhoneNumber(
        _phoneController.text,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _savedPhoneNumber = updatedUser.phoneNumber;
        _phoneController.text = updatedUser.phoneNumber ?? '';
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Numer telefonu zapisany.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error is Exception
            ? error.toString().replaceFirst('Exception: ', '')
            : 'Nie udało się zapisać numeru telefonu.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _clearPhoneNumber() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final updatedUser = await widget.onUpdatePhoneNumber(null);

      if (!mounted) {
        return;
      }

      setState(() {
        _savedPhoneNumber = updatedUser.phoneNumber;
        _phoneController.clear();
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Numer telefonu usunięty.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error is Exception
            ? error.toString().replaceFirst('Exception: ', '')
            : 'Nie udało się usunąć numeru telefonu.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Ustawienia')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Konto i kontakt', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Dodaj swój numer telefonu, aby druga osoba mogła szybko otworzyć WhatsApp do kontaktu po udostępnieniu listy.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Text('Email konta', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Text(widget.currentUser.email),
                  const SizedBox(height: 16),
                  Text(
                    'Numer telefonu do WhatsApp',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phoneController,
                    focusNode: _phoneFocusNode,
                    keyboardType: TextInputType.phone,
                    enabled: !_isSaving,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d +]')),
                    ],
                    decoration: InputDecoration(
                      hintText: '+48123123123',
                      helperText: _hasSavedPhoneNumber
                          ? 'Aktualnie zapisany numer: $_savedPhoneNumber'
                          : 'Brak zapisanego numeru telefonu.',
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _isSaving ? null : _savePhoneNumber,
                          child: Text(_phoneButtonLabel),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: _isSaving || !_hasSavedPhoneNumber
                            ? null
                            : _clearPhoneNumber,
                        child: const Text('Usuń numer'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
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
                  if (widget.savedProfile != null) ...[
                    Text(
                      'Zapisane dane logowania',
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('Backend: ${widget.savedProfile!.baseUrl}'),
                    const SizedBox(height: 4),
                    Text('Email: ${widget.savedProfile!.email}'),
                    const SizedBox(height: 16),
                  ],
                  OutlinedButton(
                    onPressed: widget.onResetLocalData == null
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
