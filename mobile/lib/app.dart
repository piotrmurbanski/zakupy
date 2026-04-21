import 'package:flutter/material.dart';

import 'features/auth/app_home_page.dart';
import 'features/auth/auth_page.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/auth_profile_store.dart';
import 'features/auth/auth_session_store.dart';
import 'features/auth/session_controller.dart';

const _brandGreen = Color(0xFF10B96B);
const _defaultApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: '',
);

ThemeData buildLightTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: _brandGreen,
    primary: _brandGreen,
    brightness: Brightness.light,
  );
  return ThemeData(colorScheme: colorScheme, useMaterial3: true);
}

ThemeData buildDarkTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: _brandGreen,
    primary: _brandGreen,
    brightness: Brightness.dark,
  );
  return ThemeData(colorScheme: colorScheme, useMaterial3: true);
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
      title: 'Listek',
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
  final AuthProfileStore _authProfileStore = SecureAuthProfileStore();
  bool _bootstrapComplete = false;

  @override
  void initState() {
    super.initState();
    _sessionController = SessionController(
      sessionStore: SecureAuthSessionStore(),
      profileStore: _authProfileStore,
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
            onUpdatePhoneNumber: _sessionController.updatePhoneNumber,
            onLogout: _sessionController.logout,
            onResetLocalData: _sessionController.resetLocalData,
            themeMode: widget.themeMode,
            onThemeModeChanged: widget.onThemeModeChanged,
            savedProfile: _sessionController.profile,
          );
        }

        return AuthPage(
          initialBaseUrl:
              _sessionController.profile?.baseUrl ?? _defaultApiBaseUrl,
          initialEmail: _sessionController.profile?.email ?? '',
          isSubmitting: state.status == SessionStatus.loading,
          errorMessage: state.errorMessage,
          themeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
          onRequestCode:
              ({
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
          onVerifyCode:
              ({
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
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
