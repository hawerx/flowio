import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/conversation_provider.dart';
import '../widgets/conversation_history_view.dart';
import '../widgets/settings_controls.dart';
import '../../../../core/utils/logger.dart';

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

  /// inicializa el provider de conversación
  Future<void> _initializeProvider() async {
    try {
      _provider = context.read<ConversationProvider>();
      await _provider.initialize();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        logger.i("ConversationPage inicializada");
      }
    } catch (e, stackTrace) {
      logger.e("Error inicializando ConversationPage", error: e, stackTrace: stackTrace);
    }
  }

  @override
  void dispose() { super.dispose(); }

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
                "Cargando Flowio...",
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.landscape) {
          return _buildLandscapeLayout();
        } else {
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
            body: _buildPortraitLayout(),
          );
        }
      },
    );
  }

  Widget _buildPortraitLayout() {
    return Column(
      children: [
        /// Historial de mensajes arriba
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.transparent,
            ),
            child: const ConversationHistoryView(),
          ),
        ),
        /// Controles debajo
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
    );
  }

  Widget _buildLandscapeLayout() {
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
      body: Row(
        children: [
          // Historial de mensajes a la izq
          Expanded(
            flex: 3,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.transparent,
              ),
              child: const ConversationHistoryView(),
            ),
          ),
          // Controles a la derecha
          Container(
            width: 350,
            decoration: const BoxDecoration(
              color: Colors.transparent,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(-2, 0),
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
