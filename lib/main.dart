import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('Sonar Notes'),
        ),
      ),
    );
  }
}
