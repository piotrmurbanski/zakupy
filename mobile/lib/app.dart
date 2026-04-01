import 'package:flutter/material.dart';

import 'core/network/api_client.dart';
import 'features/auth/auth_session_store.dart';
import 'features/lists/list_detail_page.dart';

class ZakupyApp extends StatelessWidget {
  const ZakupyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zakupy',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F6B3B)),
        useMaterial3: true
      ),
      home: const _AuthGatePage()
    );
  }
}

enum _AuthMode { login, register }

class _AuthGatePage extends StatefulWidget {
  const _AuthGatePage();

  @override
  State<_AuthGatePage> createState() => _AuthGatePageState();
}

class _AuthGatePageState extends State<_AuthGatePage> {
  final _authFormKey = GlobalKey<FormState>();
  final _listFormKey = GlobalKey<FormState>();
  final _sessionStore = SecureAuthSessionStore();
  late final TextEditingController _baseUrlController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _displayNameController;
  late final TextEditingController _listIdController;

  _AuthMode _authMode = _AuthMode.login;
  StoredAuthSession? _session;
  bool _isLoadingSession = true;
  bool _isSubmittingAuth = false;
  bool _isOpeningList = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(text: 'http://localhost:3000');
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _displayNameController = TextEditingController();
    _listIdController = TextEditingController();
    _restoreSession();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _listIdController.dispose();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    try {
      final storedSession = await _sessionStore.read();

      if (storedSession == null) {
        if (!mounted) {
          return;
        }

        setState(() {
          _session = null;
          _isLoadingSession = false;
        });
        return;
      }

      _baseUrlController.text = storedSession.baseUrl;

      final apiClient = ApiClient(
        baseUrl: storedSession.baseUrl,
        accessToken: storedSession.session.accessToken
      );
      final currentUser = await apiClient.fetchCurrentUser();

      final refreshedSession = StoredAuthSession(
        baseUrl: storedSession.baseUrl,
        session: AuthSession(
          accessToken: storedSession.session.accessToken,
          user: currentUser
        )
      );

      await _sessionStore.write(refreshedSession);

      if (!mounted) {
        return;
      }

      setState(() {
        _session = refreshedSession;
        _isLoadingSession = false;
      });
    } catch (_) {
      await _sessionStore.clear();

      if (!mounted) {
        return;
      }

      setState(() {
        _session = null;
        _isLoadingSession = false;
      });
    }
  }

  Future<void> _submitAuth() async {
    if (!(_authFormKey.currentState?.validate() ?? false)) {
      return;
    }

    final baseUrl = _baseUrlController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final displayName = _displayNameController.text.trim();

    setState(() {
      _isSubmittingAuth = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ApiClient(baseUrl: baseUrl);
      final session = switch (_authMode) {
        _AuthMode.login => await apiClient.login(
          email: email,
          password: password
        ),
        _AuthMode.register => await apiClient.register(
          email: email,
          password: password,
          displayName: displayName
        )
      };

      final storedSession = StoredAuthSession(
        baseUrl: baseUrl,
        session: session
      );
      await _sessionStore.write(storedSession);

      if (!mounted) {
        return;
      }

      setState(() {
        _session = storedSession;
        _isSubmittingAuth = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmittingAuth = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _signOut() async {
    await _sessionStore.clear();

    if (!mounted) {
      return;
    }

    setState(() {
      _session = null;
      _errorMessage = null;
    });
  }

  Future<void> _openList() async {
    if (_session == null) {
      return;
    }

    if (!(_listFormKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isOpeningList = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ApiClient(
        baseUrl: _session!.baseUrl,
        accessToken: _session!.session.accessToken
      );

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => ListDetailPage(
            apiClient: apiClient,
            listId: _listIdController.text.trim()
          )
        )
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningList = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primaryContainer.withValues(alpha: 0.85),
              theme.colorScheme.surface
            ]
          )
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _isLoadingSession
                      ? const _LoadingCard()
                      : _session == null
                          ? _AuthCard(
                              authMode: _authMode,
                              authFormKey: _authFormKey,
                              baseUrlController: _baseUrlController,
                              emailController: _emailController,
                              passwordController: _passwordController,
                              displayNameController: _displayNameController,
                              isSubmitting: _isSubmittingAuth,
                              errorMessage: _errorMessage,
                              onModeChanged: (mode) {
                                setState(() {
                                  _authMode = mode;
                                  _errorMessage = null;
                                });
                              },
                              onSubmit: _submitAuth
                            )
                          : _HomeCard(
                              session: _session!,
                              listFormKey: _listFormKey,
                              listIdController: _listIdController,
                              isOpeningList: _isOpeningList,
                              errorMessage: _errorMessage,
                              onOpenList: _openList,
                              onSignOut: _signOut
                            )
                )
              )
            )
          )
        )
      )
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Restoring session...')
          ]
        )
      )
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.authMode,
    required this.authFormKey,
    required this.baseUrlController,
    required this.emailController,
    required this.passwordController,
    required this.displayNameController,
    required this.isSubmitting,
    required this.errorMessage,
    required this.onModeChanged,
    required this.onSubmit
  });

  final _AuthMode authMode;
  final GlobalKey<FormState> authFormKey;
  final TextEditingController baseUrlController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController displayNameController;
  final bool isSubmitting;
  final String? errorMessage;
  final ValueChanged<_AuthMode> onModeChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRegister = authMode == _AuthMode.register;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: authFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Zakupy', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Sign in to your private backend.',
                style: theme.textTheme.bodyMedium
              ),
              const SizedBox(height: 20),
              Center(
                child: ToggleButtons(
                  isSelected: [
                    authMode == _AuthMode.login,
                    authMode == _AuthMode.register
                  ],
                  onPressed: (index) {
                    onModeChanged(index == 0 ? _AuthMode.login : _AuthMode.register);
                  },
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Login')
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Register')
                    )
                  ]
                )
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: baseUrlController,
                enabled: !isSubmitting,
                decoration: const InputDecoration(labelText: 'API base URL'),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';

                  if (trimmed.isEmpty) {
                    return 'API base URL is required';
                  }

                  return null;
                }
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: emailController,
                enabled: !isSubmitting,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  final trimmed = value?.trim() ?? '';

                  if (trimmed.isEmpty) {
                    return 'Email is required';
                  }

                  return null;
                }
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                enabled: !isSubmitting,
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText: isRegister ? 'At least 8 characters' : null
                ),
                obscureText: true,
                validator: (value) {
                  final trimmed = value?.trim() ?? '';

                  if (trimmed.isEmpty) {
                    return 'Password is required';
                  }

                  if (isRegister && trimmed.length < 8) {
                    return 'Password must be at least 8 characters';
                  }

                  return null;
                }
              ),
              if (isRegister) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: displayNameController,
                  enabled: !isSubmitting,
                  decoration: const InputDecoration(labelText: 'Display name'),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';

                    if (trimmed.isEmpty) {
                      return 'Display name is required';
                    }

                    return null;
                  }
                )
              ],
              const SizedBox(height: 20),
              if (errorMessage != null) ...[
                Text(
                  errorMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error
                  )
                ),
                const SizedBox(height: 12)
              ],
              FilledButton(
                onPressed: isSubmitting ? null : onSubmit,
                child: Text(
                  isSubmitting
                      ? 'Please wait...'
                      : isRegister
                          ? 'Create account'
                          : 'Sign in'
                )
              )
            ]
          )
        )
      )
    );
  }
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({
    required this.session,
    required this.listFormKey,
    required this.listIdController,
    required this.isOpeningList,
    required this.errorMessage,
    required this.onOpenList,
    required this.onSignOut
  });

  final StoredAuthSession session;
  final GlobalKey<FormState> listFormKey;
  final TextEditingController listIdController;
  final bool isOpeningList;
  final String? errorMessage;
  final VoidCallback onOpenList;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = session.session.user;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: listFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Signed in', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('${user.displayName} · ${user.email}'),
              const SizedBox(height: 4),
              Text(
                session.baseUrl,
                style: theme.textTheme.bodySmall
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: listIdController,
                enabled: !isOpeningList,
                decoration: const InputDecoration(labelText: 'List ID'),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';

                  if (trimmed.isEmpty) {
                    return 'List ID is required';
                  }

                  return null;
                }
              ),
              const SizedBox(height: 20),
              if (errorMessage != null) ...[
                Text(
                  errorMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error
                  )
                ),
                const SizedBox(height: 12)
              ],
              FilledButton(
                onPressed: isOpeningList ? null : onOpenList,
                child: Text(isOpeningList ? 'Opening...' : 'Open list')
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: isOpeningList ? null : onSignOut,
                child: const Text('Sign out')
              )
            ]
          )
        )
      )
    );
  }
}
