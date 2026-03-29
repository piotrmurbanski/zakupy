import 'package:flutter/material.dart';

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
      home: const Scaffold(
        body: Center(
          child: Text('Zakupy MVP'),
        ),
      )
    );
  }
}
