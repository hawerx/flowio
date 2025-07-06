import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/conversation_provider.dart';
import '../widgets/conversation_history_view.dart';
import '../widgets/settings_controls.dart';
import '../../../../core/utils/logger.dart';


/// La página ahora solo se encarga de:
/// - Mostrar la UI
/// - Gestionar el ciclo de vida del widget
/// - Coordinar entre la UI y el provider
/// 
/// Toda la lógica compleja ha sido movida a:
/// - ConversationManager: Coordinación de servicios
/// - Services individuales: Responsabilidades específicas
/// - ConversationProvider: Estado de la aplicación
class ConversationPage extends StatefulWidget {
  const ConversationPage({super.key});

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  late ConversationProvider _provider;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeProvider();
  }

  /// Inicializa el provider de conversación
  Future<void> _initializeProvider() async {
    try {
      _provider = context.read<ConversationProvider>();
      await _provider.initialize();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        logger.i("✅ ConversationPage inicializada");
      }
    } catch (e, stackTrace) {
      logger.e("Error inicializando ConversationPage", error: e, stackTrace: stackTrace);
    }
  }

  @override
  void dispose() {
    // El provider se dispose automáticamente por Provider
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                "Inicializando Flowio...",
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "Flowio",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Historial de mensajes (arriba)
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.transparent,
              ),
              child: const ConversationHistoryView(),
            ),
          ),
          // Controles (abajo)
          Container(
            decoration: const BoxDecoration(
              color: Colors.transparent,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: const SettingsControls(),
          ),
        ],
      ),
    );
  }
}
