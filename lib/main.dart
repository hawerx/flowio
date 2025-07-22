import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/conversation/providers/conversation_provider.dart';
import 'features/conversation/ui/pages/conversation_page.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ConversationProvider(),
      child: const FlowioApp(),
    ),
  );
}

class FlowioApp extends StatelessWidget {
  const FlowioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flowio',
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const ConversationPage(),
      debugShowCheckedModeBanner: false,
    );
  }

  /// Tema unificado para light/dark
  ThemeData _buildTheme(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: brightness,
      ),
    );
  }
}
