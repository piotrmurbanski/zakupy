import 'package:flutter/material.dart';

import '../../core/theme/zakupy_logo.dart';
import '../../core/theme/theme_mode_menu.dart';

typedef RequestCodeSubmit =
    Future<void> Function({
      required String baseUrl,
      required String email,
      String? displayName,
    });

typedef VerifyCodeSubmit =
    Future<void> Function({
      required String baseUrl,
      required String email,
      required String code,
      String? displayName,
    });

enum _AuthStep { requestCode, verifyCode }

class AuthPage extends StatefulWidget {
  const AuthPage({
    required this.onRequestCode,
    required this.onVerifyCode,
    required this.themeMode,
    required this.onThemeModeChanged,
    this.initialBaseUrl = '',
    this.initialEmail = '',
    this.isSubmitting = false,
    this.errorMessage,
    super.key,
  });

  final RequestCodeSubmit onRequestCode;
  final VerifyCodeSubmit onVerifyCode;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final String initialBaseUrl;
  final String initialEmail;
  final bool isSubmitting;
  final String? errorMessage;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _baseUrlController;
  late final TextEditingController _emailController;
  late final TextEditingController _displayNameController;
  late final TextEditingController _codeController;

  _AuthStep _step = _AuthStep.requestCode;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(text: widget.initialBaseUrl);
    _emailController = TextEditingController(text: widget.initialEmail);
    _displayNameController = TextEditingController();
    _codeController = TextEditingController();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _emailController.dispose();
    _displayNameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    await widget.onRequestCode(
      baseUrl: _baseUrlController.text.trim(),
      email: _emailController.text.trim(),
      displayName: _normalizedOptionalText(_displayNameController.text),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _step = _AuthStep.verifyCode;
      _codeController.clear();
    });
  }

  Future<void> _verifyCode() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    await widget.onVerifyCode(
      baseUrl: _baseUrlController.text.trim(),
      email: _emailController.text.trim(),
      code: _codeController.text.trim(),
      displayName: _normalizedOptionalText(_displayNameController.text),
    );
  }

  void _editEmail() {
    setState(() {
      _step = _AuthStep.requestCode;
      _codeController.clear();
    });
  }

  String? _normalizedOptionalText(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRequestStep = _step == _AuthStep.requestCode;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ZakupyLogo(size: 30, showGlow: false),
            SizedBox(width: 12),
            Text('Listek'),
          ],
        ),
        actions: [
          ThemeModeMenuButton(
            currentThemeMode: widget.themeMode,
            onSelected: widget.onThemeModeChanged,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primaryContainer.withValues(alpha: 0.9),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: ZakupyLogo(size: 92)),
                          const SizedBox(height: 20),
                          Text('Listek', style: theme.textTheme.headlineMedium),
                          const SizedBox(height: 8),
                          Text(
                            isRequestStep
                                ? 'Podaj swój adres e-mail, aby otrzymać kod logowania. Na prawdziwym telefonie użyj adresu Tailscale albo Caddy zamiast localhost.'
                                : 'Wpisz kod wysłany na adres ${_emailController.text.trim()}, aby zaufać temu urządzeniu.',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 24),
                          if (widget.errorMessage != null &&
                              widget.errorMessage!.trim().isNotEmpty) ...[
                            _ErrorBanner(message: widget.errorMessage!),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            controller: _baseUrlController,
                            decoration: const InputDecoration(
                              labelText: 'Adres API',
                              hintText: 'https://listek.your-tailnet.ts.net',
                            ),
                            keyboardType: TextInputType.url,
                            enabled: !widget.isSubmitting,
                            validator: (value) {
                              final trimmed = value?.trim() ?? '';

                              if (trimmed.isEmpty) {
                                return 'Adres API jest wymagany';
                              }

                              final uri = Uri.tryParse(trimmed);

                              if (uri == null ||
                                  !uri.hasScheme ||
                                  uri.host.isEmpty) {
                                return 'Podaj poprawny adres URL, na przykład https://listek.your-tailnet.ts.net';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                            ),
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            textInputAction: TextInputAction.next,
                            enabled: !widget.isSubmitting,
                            validator: (value) {
                              final trimmed = value?.trim() ?? '';
                              final emailPattern = RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              );

                              if (!emailPattern.hasMatch(trimmed)) {
                                return 'Podaj poprawny adres e-mail';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _displayNameController,
                            decoration: const InputDecoration(
                              labelText: 'Nazwa wyświetlana (opcjonalnie)',
                            ),
                            textCapitalization: TextCapitalization.words,
                            enabled: !widget.isSubmitting,
                            validator: (value) {
                              final trimmed = value?.trim() ?? '';

                              if (trimmed.isEmpty) {
                                return null;
                              }

                              if (trimmed.length < 2) {
                                return 'Nazwa wyświetlana musi mieć co najmniej 2 znaki';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          if (!isRequestStep) ...[
                            TextFormField(
                              controller: _codeController,
                              decoration: const InputDecoration(
                                labelText: 'Kod logowania',
                              ),
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              enabled: !widget.isSubmitting,
                              onFieldSubmitted: (_) => _verifyCode(),
                              validator: (value) {
                                final trimmed = value?.trim() ?? '';

                                if (trimmed.isEmpty) {
                                  return 'Kod logowania jest wymagany';
                                }

                                if (trimmed.length < 4) {
                                  return 'Wpisz kod z wiadomości e-mail';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                          ] else
                            const SizedBox(height: 8),
                          FilledButton(
                            onPressed: widget.isSubmitting
                                ? null
                                : isRequestStep
                                ? _requestCode
                                : _verifyCode,
                            child: widget.isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    isRequestStep ? 'Wyślij kod' : 'Zweryfikuj kod',
                                  ),
                          ),
                          const SizedBox(height: 12),
                          if (!isRequestStep)
                            TextButton(
                              onPressed: widget.isSubmitting
                                  ? null
                                  : _editEmail,
                              child: const Text('Użyj innego adresu e-mail'),
                            ),
                          if (!isRequestStep)
                            TextButton(
                              onPressed: widget.isSubmitting
                                  ? null
                                  : _requestCode,
                              child: const Text('Wyślij kod ponownie'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
