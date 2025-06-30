import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/conversation/providers/conversation_provider.dart';
import 'features/conversation/ui/pages/conversation_page.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => ConversationProvider(),
      child: const FlowioApp(),
    ),
  );
}

class FlowioApp extends StatelessWidget {
  const FlowioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flowio Translator',
      theme: ThemeData.light(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
      ),
      themeMode: ThemeMode.system,
      home: const ConversationPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}