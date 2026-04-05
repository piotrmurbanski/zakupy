import 'package:flutter/material.dart';

import 'features/auth/app_home_page.dart';
import 'features/auth/auth_page.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/auth_session_store.dart';
import 'features/auth/session_controller.dart';

const _defaultApiBaseUrl =
    String.fromEnvironment('API_BASE_URL', defaultValue: '');

ThemeData buildLightTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2F6B3B),
      brightness: Brightness.light,
    ),
    useMaterial3: true,
  );
}

ThemeData buildDarkTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2F6B3B),
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  );
}

class ZakupyApp extends StatefulWidget {
  const ZakupyApp({super.key});

  @override
  State<ZakupyApp> createState() => _ZakupyAppState();
}

class _ZakupyAppState extends State<ZakupyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _setThemeMode(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zakupy',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: _themeMode,
      home: _AppBootstrapper(
        themeMode: _themeMode,
        onThemeModeChanged: _setThemeMode,
      ),
    );
  }
}

class _AppBootstrapper extends StatefulWidget {
  const _AppBootstrapper({
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<_AppBootstrapper> createState() => _AppBootstrapperState();
}

class _AppBootstrapperState extends State<_AppBootstrapper> {
  late final SessionController _sessionController;
  final AuthRepository _authRepository = const AuthRepository();
  bool _bootstrapComplete = false;

  @override
  void initState() {
    super.initState();
    _sessionController = SessionController(
      sessionStore: SecureAuthSessionStore(),
      authRepository: _authRepository,
    );
    _restoreSession();
  }

  @override
  void dispose() {
    _sessionController.dispose();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    await _sessionController.bootstrap();

    if (!mounted) {
      return;
    }

    setState(() {
      _bootstrapComplete = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SessionState>(
      valueListenable: _sessionController,
      builder: (context, state, _) {
        if (!_bootstrapComplete) {
          return const _BootstrapLoadingPage();
        }

        if (state.status == SessionStatus.authenticated) {
          return AppHomePage(
            session: state.session!,
            authRepository: _authRepository,
            onLogout: _sessionController.logout,
            themeMode: widget.themeMode,
            onThemeModeChanged: widget.onThemeModeChanged,
          );
        }

        return AuthPage(
          initialBaseUrl: _defaultApiBaseUrl,
          isSubmitting: state.status == SessionStatus.loading,
          errorMessage: state.errorMessage,
          themeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
          onRequestCode: ({
            required String baseUrl,
            required String email,
            String? displayName,
          }) {
            return _sessionController.requestCode(
              baseUrl: baseUrl,
              email: email,
              displayName: displayName,
            );
          },
          onVerifyCode: ({
            required String baseUrl,
            required String email,
            required String code,
            String? displayName,
          }) {
            return _sessionController.verifyCode(
              baseUrl: baseUrl,
              email: email,
              code: code,
              displayName: displayName,
            );
          },
        );
      },
    );
  }
}

class _BootstrapLoadingPage extends StatelessWidget {
  const _BootstrapLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
