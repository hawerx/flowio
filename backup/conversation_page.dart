// import 'package:flutter/material.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:provider/provider.dart';
// import '../../../../core/utils/logger.dart';
// import '../../providers/conversation_provider.dart';
// import '../../services/audio_manager.dart';
// import '../../services/websocket_manager.dart';
// import '../../services/tts_manager.dart';
// import '../../services/conversation_manager.dart';
// import '../widgets/conversation_history_view.dart';
// import '../widgets/settings_controls.dart';
// import '../widgets/status_indicator.dart';

// class ConversationPage extends StatefulWidget {
//   const ConversationPage({super.key});

//   @override
//   State<ConversationPage> createState() => _ConversationPageState();
// }

// class _ConversationPageState extends State<ConversationPage> {
//   late ConversationCoordinator _coordinator;
//   bool _isInitialized = false;

//   @override
//   void initState() {
//     super.initState();
//     _initializeApp();
//   }

//   Future<void> _initializeApp() async {
//     try {
      
//       final provider = context.read<ConversationProvider>();
      
//       _coordinator = ConversationCoordinator(
//         audioManager: AudioManager(),
//         webSocketManager: WebSocketManager(),
//         ttsManager: TtsManager(),
//         provider: provider,
//       );

//       await _coordinator.initialize();
//       provider.addListener(_onStateChange);
      
//       _isInitialized = true;
//       logger.i("✅ ConversationPage inicializada");
//     } catch (e, stackTrace) {
//       logger.e("❌ Error inicializando app", error: e, stackTrace: stackTrace);
//     }
//   }

//   void _onStateChange() {
//     if (!mounted || !_isInitialized) return;
    
//     final provider = context.read<ConversationProvider>();
    
//     if (provider.isConversing && !_coordinator.state.isActive) {
//       _startConversation();
//     } else if (!provider.isConversing && _coordinator.state.isActive) {
//       _coordinator.stopConversation();
//     }
//   }

//   Future<void> _startConversation() async {
//     final status = await Permission.microphone.request();
//     if (!status.isGranted) {
//       if (mounted) {
//         context.read<ConversationProvider>().stopConversation();
//       }
//       return;
//     }

//     try {
//       await _coordinator.startConversation();
//     } catch (e, stackTrace) {
//       logger.e("❌ Error iniciando conversación", error: e, stackTrace: stackTrace);
//       if (mounted) {
//         context.read<ConversationProvider>().stopConversation();
//       }
//     }
//   }

//   @override
//   void dispose() {
//     _coordinator.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Flowio Translator")),
//       body: Column(
//         children: [
//           const SettingsControls(),
//           const Divider(height: 1),
//           const StatusIndicator(),
//           const Divider(height: 1),
//           Expanded(child: ConversationHistoryView()),
//         ],
//       ),
//     );
//   }
// }