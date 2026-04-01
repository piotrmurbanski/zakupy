import 'package:flutter/material.dart';

import 'core/network/api_client.dart';
import 'features/auth/auth_models.dart';
import 'features/auth/auth_session_store.dart';
import 'features/lists/list_detail_page.dart';

const _defaultApiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');

class ZakupyApp extends StatelessWidget {
  const ZakupyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zakupy',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F6B3B)),
        useMaterial3: true,
      ),
      home: const _AppShell(),
    );
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  final SecureAuthSessionStore _sessionStore = SecureAuthSessionStore();

  bool _isLoading = true;
  StoredAuthSession? _storedSession;
  String _lastBaseUrl = _defaultApiBaseUrl;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      final stored = await _sessionStore.read();
      final baseUrl = stored?.baseUrl ?? _defaultApiBaseUrl;

      if (stored == null) {
        if (!mounted) {
          return;
        }

        setState(() {
          _storedSession = null;
          _lastBaseUrl = baseUrl;
          _isLoading = false;
        });
        return;
      }

      final apiClient = ApiClient(
        baseUrl: stored.baseUrl,
        accessToken: stored.session.accessToken,
      );
      final currentUser = await apiClient.fetchCurrentUser();
      final refreshed = StoredAuthSession(
        baseUrl: stored.baseUrl,
        session: AuthSession(
          accessToken: stored.session.accessToken,
          user: currentUser,
        ),
      );

      await _sessionStore.write(refreshed);

      if (!mounted) {
        return;
      }

      setState(() {
        _storedSession = refreshed;
        _lastBaseUrl = refreshed.baseUrl;
        _isLoading = false;
      });
    } catch (_) {
      await _sessionStore.clear();

      if (!mounted) {
        return;
      }

      setState(() {
        _storedSession = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _finishAuthentication({
    required String baseUrl,
    required AuthSession session,
  }) async {
    final storedSession = StoredAuthSession(
      baseUrl: baseUrl,
      session: session,
    );

    await _sessionStore.write(storedSession);

    if (!mounted) {
      return;
    }

    setState(() {
      _storedSession = storedSession;
      _lastBaseUrl = storedSession.baseUrl;
    });
  }

  Future<void> _updateSession(StoredAuthSession storedSession) async {
    await _sessionStore.write(storedSession);

    if (!mounted) {
      return;
    }

    setState(() {
      _storedSession = storedSession;
      _lastBaseUrl = storedSession.baseUrl;
    });
  }

  Future<void> _logout() async {
    await _sessionStore.clear();

    if (!mounted) {
      return;
    }

    setState(() {
      _storedSession = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final storedSession = _storedSession;
    if (storedSession == null) {
      return _AuthPage(
        initialBaseUrl: _lastBaseUrl,
        onAuthenticated: _finishAuthentication,
      );
    }

    return _ListsHomePage(
      session: storedSession,
      onSessionChanged: _updateSession,
      onLogout: _logout,
    );
  }
}

class _AuthPage extends StatefulWidget {
  const _AuthPage({
    required this.initialBaseUrl,
    required this.onAuthenticated,
  });

  final String initialBaseUrl;
  final Future<void> Function({
    required String baseUrl,
    required AuthSession session,
  }) onAuthenticated;

  @override
  State<_AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<_AuthPage> with SingleTickerProviderStateMixin {
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  late final TabController _tabController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _loginEmailController;
  late final TextEditingController _loginPasswordController;
  late final TextEditingController _registerNameController;
  late final TextEditingController _registerEmailController;
  late final TextEditingController _registerPasswordController;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _baseUrlController = TextEditingController(text: widget.initialBaseUrl);
    _loginEmailController = TextEditingController();
    _loginPasswordController = TextEditingController();
    _registerNameController = TextEditingController();
    _registerEmailController = TextEditingController();
    _registerPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _baseUrlController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerNameController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (!(_loginFormKey.currentState?.validate() ?? false) || !_validateBaseUrl()) {
      return;
    }

    await _submit(() async {
      final client = ApiClient(baseUrl: _baseUrlController.text);
      final session = await client.login(
        email: _loginEmailController.text,
        password: _loginPasswordController.text,
      );

      await widget.onAuthenticated(
        baseUrl: client.baseUrl,
        session: session,
      );
    });
  }

  Future<void> _submitRegistration() async {
    if (!(_registerFormKey.currentState?.validate() ?? false) || !_validateBaseUrl()) {
      return;
    }

    await _submit(() async {
      final client = ApiClient(baseUrl: _baseUrlController.text);
      final session = await client.register(
        email: _registerEmailController.text,
        password: _registerPasswordController.text,
        displayName: _registerNameController.text,
      );

      await widget.onAuthenticated(
        baseUrl: client.baseUrl,
        session: session,
      );
    });
  }

  bool _validateBaseUrl() {
    final validation = _validateApiBaseUrl(_baseUrlController.text);
    if (validation == null) {
      return true;
    }

    setState(() {
      _errorMessage = validation;
    });
    return false;
  }

  Future<void> _submit(Future<void> Function() action) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await action();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Unexpected error. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
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
              theme.colorScheme.primaryContainer.withValues(alpha: 0.9),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                margin: const EdgeInsets.all(24),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Zakupy', style: theme.textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to your private shopping backend. On real phones, use your Tailscale or Caddy URL instead of localhost.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _baseUrlController,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'API base URL',
                          hintText: 'https://zakupy.your-tailnet.ts.net',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TabBar(
                        controller: _tabController,
                        tabs: const [
                          Tab(text: 'Log in'),
                          Tab(text: 'Register'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 320,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildLoginForm(),
                            _buildRegisterForm(),
                          ],
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _loginEmailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Email'),
            validator: _validateEmail,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _loginPasswordController,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            decoration: const InputDecoration(labelText: 'Password'),
            validator: _validatePassword,
            onFieldSubmitted: (_) => _submitLogin(),
          ),
          const Spacer(),
          FilledButton(
            onPressed: _isSubmitting ? null : _submitLogin,
            child: Text(_isSubmitting ? 'Signing in...' : 'Log in'),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Form(
      key: _registerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _registerNameController,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            decoration: const InputDecoration(labelText: 'Display name'),
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.length < 2) {
                return 'Display name must be at least 2 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _registerEmailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.newUsername, AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Email'),
            validator: _validateEmail,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _registerPasswordController,
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            decoration: const InputDecoration(labelText: 'Password'),
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.length < 8) {
                return 'Password must be at least 8 characters';
              }
              return null;
            },
            onFieldSubmitted: (_) => _submitRegistration(),
          ),
          const Spacer(),
          FilledButton(
            onPressed: _isSubmitting ? null : _submitRegistration,
            child: Text(_isSubmitting ? 'Creating account...' : 'Register'),
          ),
        ],
      ),
    );
  }
}

class _ListsHomePage extends StatefulWidget {
  const _ListsHomePage({
    required this.session,
    required this.onSessionChanged,
    required this.onLogout,
  });

  final StoredAuthSession session;
  final Future<void> Function(StoredAuthSession session) onSessionChanged;
  final Future<void> Function() onLogout;

  @override
  State<_ListsHomePage> createState() => _ListsHomePageState();
}

class _ListsHomePageState extends State<_ListsHomePage> {
  late ApiClient _apiClient;
  final List<ShoppingListSummary> _lists = <ShoppingListSummary>[];

  bool _isLoading = true;
  bool _isUpdating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _apiClient = _buildClient(widget.session);
    _loadLists();
  }

  @override
  void didUpdateWidget(covariant _ListsHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.session.baseUrl != widget.session.baseUrl ||
        oldWidget.session.session.accessToken != widget.session.session.accessToken) {
      _apiClient = _buildClient(widget.session);
      _loadLists();
    }
  }

  ApiClient _buildClient(StoredAuthSession session) {
    return ApiClient(
      baseUrl: session.baseUrl,
      accessToken: session.session.accessToken,
    );
  }

  Future<void> _loadLists({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final user = await _apiClient.fetchCurrentUser();
      final lists = await _apiClient.fetchLists();

      if (!mounted) {
        return;
      }

      final refreshedSession = StoredAuthSession(
        baseUrl: widget.session.baseUrl,
        session: AuthSession(
          accessToken: widget.session.session.accessToken,
          user: user,
        ),
      );
      await widget.onSessionChanged(refreshedSession);

      if (!mounted) {
        return;
      }

      setState(() {
        _lists
          ..clear()
          ..addAll(lists);
        _isLoading = false;
        _errorMessage = null;
      });
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await widget.onLogout();
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    }
  }

  Future<void> _createList() async {
    final name = await _showTextPrompt(
      title: 'Create list',
      label: 'List name',
      actionLabel: 'Create',
    );

    if (name == null) {
      return;
    }

    await _runMutation(() async {
      await _apiClient.createList(name);
      await _loadLists(silent: true);
    });
  }

  Future<void> _shareList(ShoppingListSummary list) async {
    final email = await _showTextPrompt(
      title: 'Share list',
      label: 'User email',
      actionLabel: 'Share',
      keyboardType: TextInputType.emailAddress,
    );

    if (email == null) {
      return;
    }

    await _runMutation(() async {
      final member = await _apiClient.shareList(
        listId: list.id,
        email: email,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Shared with ${member.user.email}.')),
      );
    });
  }

  Future<void> _editBackendUrl() async {
    final updatedBaseUrl = await _showTextPrompt(
      title: 'Backend URL',
      label: 'API base URL',
      actionLabel: 'Save',
      initialValue: widget.session.baseUrl,
      keyboardType: TextInputType.url,
    );

    if (updatedBaseUrl == null) {
      return;
    }

    final validation = _validateApiBaseUrl(updatedBaseUrl);
    if (validation != null) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validation)),
      );
      return;
    }

    final normalizedBaseUrl = ApiClient(baseUrl: updatedBaseUrl.trim()).baseUrl;
    final updatedSession = StoredAuthSession(
      baseUrl: normalizedBaseUrl,
      session: widget.session.session,
    );
    await widget.onSessionChanged(updatedSession);

    if (!mounted) {
      return;
    }

    setState(() {
      _apiClient = _buildClient(updatedSession);
    });

    await _loadLists();
  }

  Future<void> _runMutation(Future<void> Function() action) async {
    setState(() {
      _isUpdating = true;
    });

    try {
      await action();
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await widget.onLogout();
        return;
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<String?> _showTextPrompt({
    required String title,
    required String label,
    required String actionLabel,
    String initialValue = '',
    TextInputType? keyboardType,
  }) {
    final controller = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              autofocus: true,
              decoration: InputDecoration(labelText: label),
              validator: (value) {
                if ((value?.trim() ?? '').isEmpty) {
                  return '$label is required';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) {
                  return;
                }

                Navigator.of(context).pop(controller.text.trim());
              },
              child: Text(actionLabel),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openList(ShoppingListSummary list) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ListDetailPage(
          apiClient: _apiClient,
          listId: list.id,
          listName: list.name,
          onUnauthorized: widget.onLogout,
        ),
      ),
    );

    await _loadLists(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = widget.session.session.user.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your lists'),
        actions: [
          IconButton(
            onPressed: _isUpdating ? null : () => _loadLists(),
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'backend') {
                await _editBackendUrl();
              } else if (value == 'logout') {
                await widget.onLogout();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'backend',
                child: Text('Backend URL'),
              ),
              PopupMenuItem<String>(
                value: 'logout',
                child: Text('Log out'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUpdating ? null : _createList,
        icon: const Icon(Icons.add),
        label: const Text('New list'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadLists(silent: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            _AccountCard(
              session: widget.session,
              onEditBackendUrl: () {
                _editBackendUrl();
              },
            ),
            const SizedBox(height: 16),
            if (_isLoading && _lists.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null && _lists.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: _ErrorState(
                  message: _errorMessage!,
                  onRetry: _loadLists,
                ),
              )
            else if (_lists.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 32),
                child: Center(
                  child: Text('No lists yet. Create the first one to get started.'),
                ),
              )
            else
              ..._lists.map(
                (list) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: ListTile(
                      onTap: () => _openList(list),
                      title: Text(list.name),
                      subtitle: Text(
                        list.isOwnedBy(currentUserId) ? 'Owner' : 'Shared with you',
                      ),
                      trailing: list.isOwnedBy(currentUserId)
                          ? IconButton(
                              tooltip: 'Share list',
                              onPressed: _isUpdating ? null : () => _shareList(list),
                              icon: const Icon(Icons.person_add_alt_1_outlined),
                            )
                          : const Icon(Icons.chevron_right),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.session,
    required this.onEditBackendUrl,
  });

  final StoredAuthSession session;
  final VoidCallback onEditBackendUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(session.session.user.displayName, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(session.session.user.email),
            const SizedBox(height: 12),
            Text(
              session.baseUrl,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: onEditBackendUrl,
                  child: const Text('Change backend'),
                ),
                const Chip(
                  label: Text('Session saved on this device'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function({bool silent}) onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.error_outline, size: 48),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => onRetry(),
          child: const Text('Retry'),
        ),
      ],
    );
  }
}

String? _validateApiBaseUrl(String value) {
  final trimmed = value.trim();

  if (trimmed.isEmpty) {
    return 'API base URL is required';
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return 'Enter a full URL, for example https://zakupy.your-tailnet.ts.net';
  }

  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return 'Only http and https URLs are supported';
  }

  return null;
}

String? _validateEmail(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty || !trimmed.contains('@')) {
    return 'Enter a valid email address';
  }
  return null;
}

String? _validatePassword(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return 'Password is required';
  }
  return null;
}
