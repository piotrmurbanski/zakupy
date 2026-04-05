import 'package:flutter/material.dart';

import '../../core/theme/theme_mode_menu.dart';

typedef LoginSubmit = Future<void> Function(
    {required String baseUrl, required String email, required String password});

typedef RegisterSubmit = Future<void> Function(
    {required String baseUrl,
    required String email,
    required String password,
    required String displayName});

class AuthPage extends StatefulWidget {
  const AuthPage(
      {required this.onLogin,
      required this.onRegister,
      required this.themeMode,
      required this.onThemeModeChanged,
      this.initialBaseUrl = '',
      this.isSubmitting = false,
      this.errorMessage,
      super.key});

  final LoginSubmit onLogin;
  final RegisterSubmit onRegister;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final String initialBaseUrl;
  final bool isSubmitting;
  final String? errorMessage;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _baseUrlController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _displayNameController;

  bool _isRegisterMode = false;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(text: widget.initialBaseUrl);
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _displayNameController = TextEditingController();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final baseUrl = _baseUrlController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (_isRegisterMode) {
      await widget.onRegister(
          baseUrl: baseUrl,
          email: email,
          password: password,
          displayName: _displayNameController.text.trim());
      return;
    }

    await widget.onLogin(baseUrl: baseUrl, email: email, password: password);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
        appBar: AppBar(
          title: const Text('Zakupy'),
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
                  theme.colorScheme.surface
                ])),
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
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Text('Zakupy',
                                                  style: theme.textTheme
                                                      .headlineMedium),
                                              const SizedBox(height: 8),
                                              Text(
                                                  _isRegisterMode
                                                      ? 'Create your private account and connect to your home backend.'
                                                      : 'Sign in to your private shopping lists. On real phones, use your Tailscale or Caddy URL instead of localhost.',
                                                  style: theme
                                                      .textTheme.bodyMedium),
                                              const SizedBox(height: 24),
                                              if (widget.errorMessage != null &&
                                                  widget.errorMessage!
                                                      .trim()
                                                      .isNotEmpty) ...[
                                                _ErrorBanner(
                                                    message:
                                                        widget.errorMessage!),
                                                const SizedBox(height: 16)
                                              ],
                                              TextFormField(
                                                  controller:
                                                      _baseUrlController,
                                                  decoration: const InputDecoration(
                                                      labelText: 'API base URL',
                                                      hintText:
                                                          'https://zakupy.your-tailnet.ts.net'),
                                                  keyboardType:
                                                      TextInputType.url,
                                                  enabled: !widget.isSubmitting,
                                                  validator: (value) {
                                                    final trimmed =
                                                        value?.trim() ?? '';

                                                    if (trimmed.isEmpty) {
                                                      return 'API base URL is required';
                                                    }

                                                    final uri =
                                                        Uri.tryParse(trimmed);

                                                    if (uri == null ||
                                                        !uri.hasScheme ||
                                                        uri.host.isEmpty) {
                                                      return 'Enter a valid URL, for example https://zakupy.your-tailnet.ts.net';
                                                    }

                                                    return null;
                                                  }),
                                              const SizedBox(height: 12),
                                              if (_isRegisterMode) ...[
                                                TextFormField(
                                                    controller:
                                                        _displayNameController,
                                                    decoration:
                                                        const InputDecoration(
                                                            labelText:
                                                                'Display name'),
                                                    textCapitalization:
                                                        TextCapitalization
                                                            .words,
                                                    enabled:
                                                        !widget.isSubmitting,
                                                    validator: (value) {
                                                      final trimmed =
                                                          value?.trim() ?? '';

                                                      if (trimmed.length < 2) {
                                                        return 'Display name must be at least 2 characters';
                                                      }

                                                      return null;
                                                    }),
                                                const SizedBox(height: 12)
                                              ],
                                              TextFormField(
                                                  controller: _emailController,
                                                  decoration:
                                                      const InputDecoration(
                                                          labelText: 'Email'),
                                                  keyboardType: TextInputType
                                                      .emailAddress,
                                                  autocorrect: false,
                                                  textInputAction:
                                                      TextInputAction.next,
                                                  enabled: !widget.isSubmitting,
                                                  validator: (value) {
                                                    final trimmed =
                                                        value?.trim() ?? '';
                                                    final emailPattern = RegExp(
                                                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

                                                    if (!emailPattern
                                                        .hasMatch(trimmed)) {
                                                      return 'Enter a valid email address';
                                                    }

                                                    return null;
                                                  }),
                                              const SizedBox(height: 12),
                                              TextFormField(
                                                  controller:
                                                      _passwordController,
                                                  decoration: InputDecoration(
                                                      labelText: _isRegisterMode
                                                          ? 'Password'
                                                          : 'Password'),
                                                  obscureText: true,
                                                  textInputAction:
                                                      TextInputAction.done,
                                                  enabled: !widget.isSubmitting,
                                                  onFieldSubmitted: (_) =>
                                                      _submit(),
                                                  validator: (value) {
                                                    final raw = value ?? '';

                                                    if (raw.isEmpty) {
                                                      return 'Password is required';
                                                    }

                                                    if (_isRegisterMode &&
                                                        raw.length < 8) {
                                                      return 'Password must be at least 8 characters';
                                                    }

                                                    return null;
                                                  }),
                                              const SizedBox(height: 20),
                                              FilledButton(
                                                  onPressed: widget.isSubmitting
                                                      ? null
                                                      : _submit,
                                                  child: widget.isSubmitting
                                                      ? const SizedBox(
                                                          width: 20,
                                                          height: 20,
                                                          child:
                                                              CircularProgressIndicator(
                                                                  strokeWidth:
                                                                      2))
                                                      : Text(_isRegisterMode
                                                          ? 'Create account'
                                                          : 'Log in')),
                                              const SizedBox(height: 12),
                                              TextButton(
                                                  onPressed: widget.isSubmitting
                                                      ? null
                                                      : () {
                                                          setState(() {
                                                            _isRegisterMode =
                                                                !_isRegisterMode;
                                                          });
                                                        },
                                                  child: Text(_isRegisterMode
                                                      ? 'Already have an account? Log in'
                                                      : 'Need an account? Register'))
                                            ]))))))))));
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
            borderRadius: BorderRadius.circular(12)),
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Icon(Icons.error_outline,
                  color: Theme.of(context).colorScheme.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(message,
                      style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onErrorContainer)))
            ])));
  }
}
