import 'package:flutter/material.dart';

import 'core/network/api_client.dart';
import 'features/lists/lists_overview_page.dart';

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
      home: const _LauncherPage()
    );
  }
}

class _LauncherPage extends StatefulWidget {
  const _LauncherPage();

  @override
  State<_LauncherPage> createState() => _LauncherPageState();
}

class _LauncherPageState extends State<_LauncherPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _baseUrlController;
  late final TextEditingController _accessTokenController;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(text: 'http://localhost:3000');
    _accessTokenController = TextEditingController();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _accessTokenController.dispose();
    super.dispose();
  }

  void _openLists() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final apiClient = ApiClient(
      baseUrl: _baseUrlController.text,
      accessToken: _accessTokenController.text.trim()
    );

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ListsOverviewPage(apiClient: apiClient)
      )
    );
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
              theme.colorScheme.primaryContainer.withOpacity(0.85),
              theme.colorScheme.surface
            ]
          )
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              margin: const EdgeInsets.all(24),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Zakupy',
                        style: theme.textTheme.headlineMedium
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Connect to your private backend and browse your shopping lists.',
                        style: theme.textTheme.bodyMedium
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _baseUrlController,
                        decoration: const InputDecoration(
                          labelText: 'API base URL'
                        ),
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
                        controller: _accessTokenController,
                        decoration: const InputDecoration(
                          labelText: 'Access token'
                        ),
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';

                          if (trimmed.isEmpty) {
                            return 'Access token is required';
                          }

                          return null;
                        }
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _openLists,
                        child: const Text('Open my lists')
                      )
                    ]
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
