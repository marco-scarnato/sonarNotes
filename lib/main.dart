import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/notes/presentation/home_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: SonarNotesApp(),
    ),
  );
}

class SonarNotesApp extends StatelessWidget {
  const SonarNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sonar Notes',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
