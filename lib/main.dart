import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/providers/conversation_provider.dart';
import 'features/pages/conversation_page.dart';

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

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flowio',
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
        fontFamily: 'Inter',
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        fontFamily: 'Inter',
      ),
      themeMode: ThemeMode.system,
      home: const ConversationPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
