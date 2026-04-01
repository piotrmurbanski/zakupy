import 'package:flutter/material.dart';

import 'features/auth/app_home_page.dart';
import 'features/auth/auth_page.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/auth_session_store.dart';
import 'features/auth/session_controller.dart';

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
      home: const _AppBootstrapper(),
    );
  }
}

class _AppBootstrapper extends StatefulWidget {
  const _AppBootstrapper();

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
          );
        }

        return AuthPage(
          isSubmitting: state.status == SessionStatus.loading,
          errorMessage: state.errorMessage,
          onLogin: ({
            required String baseUrl,
            required String email,
            required String password,
          }) {
            return _sessionController.login(
              baseUrl: baseUrl,
              email: email,
              password: password,
            );
          },
          onRegister: ({
            required String baseUrl,
            required String email,
            required String password,
            required String displayName,
          }) {
            return _sessionController.register(
              baseUrl: baseUrl,
              email: email,
              password: password,
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
