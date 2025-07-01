import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:vad/vad.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../../../core/utils/logger.dart';
import '../../providers/conversation_provider.dart';
import '../widgets/conversation_history_view.dart';
import '../widgets/settings_controls.dart';
import '../../../../core/models/message.dart';

// [IMPORTANT!] INITIAL CONFIGURATION FOR BACKEND CONNECTION
const bool    useLocalBackend   = true;                   // Flag to use local backend or Huggin Face
const String  localBackendIp    = "192.168.2.108";        // IPv4 para
const String  hfBackendUrl      = "wss://hawerx-flowio-backend.hf.space/ws/translate"; // HF  backend URL

// [IMPORTANT!] INITIAL CONFIG FOR ASSET PATHS
const String  nextTurnSoundFilePath = "assets/sounds/beep.mp3"; 

class ConversationPage extends StatefulWidget {
  const ConversationPage({super.key});

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  
  final AudioRecorder _audioRecorder  = AudioRecorder();
  final FlutterTts    _flutterTts     = FlutterTts();
  final AudioPlayer   _beepPlayer     = AudioPlayer();


  VadHandlerBase? _vad;
  WebSocketChannel? _channel;
  StreamSubscription? _webSocketSub;
  StreamSubscription<List<int>>? _audioStreamSub;
  StreamSubscription? _onSpeechStartSub;
  StreamSubscription? _onSpeechEndSub;

  bool _isProcessingTts = false;
  bool _isInitialized = false;
  bool _vadIsListening = false;
  bool _isFullyDisconnected = false; // Nuevo: para controlar estado completo

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await _initTts();
      await _initVad();
      await _loadBeepSound();
      context.read<ConversationProvider>().addListener(_onStateChange);
      _isInitialized = true;
      logger.i("✅ ConversationPage inicializada");
    } catch (e, stackTrace) {
      logger.e("Error inicializando", error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _initVad() async {
    try {
      // Limpiar VAD previo si existe
      if (_vad != null) {
        await _cleanupVad();
      }
      
      _vad = VadHandler.create(isDebug: false);
      
      _onSpeechStartSub = _vad?.onRealSpeechStart.listen((_) {
        if (_vadIsListening && !_isProcessingTts && _isInitialized && !_isFullyDisconnected) {
          logger.i("🎤 VAD: Inicio de habla detectado");
        }
      });
      
      _onSpeechEndSub = _vad?.onSpeechEnd.listen((_) {
        if (_vadIsListening && !_isProcessingTts && _isInitialized && !_isFullyDisconnected) {
          logger.i("🛑 VAD: Fin de habla detectado");
          _onSpeechEndDetected();
        }
      });

      logger.i("✅ VAD configurado");
    } catch (e, stackTrace) {
      logger.e("Error configurando VAD", error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _cleanupVad() async {
    try {
      logger.i("🧹 Limpiando VAD anterior...");
      
      await _onSpeechStartSub?.cancel();
      await _onSpeechEndSub?.cancel();
      _onSpeechStartSub = null;
      _onSpeechEndSub = null;
      
      if (_vad != null && _vadIsListening) {
        await _vad!.stopListening();
      }
      
      _vadIsListening = false;
      _vad = null;
      
      logger.i("✅ VAD anterior limpiado");
    } catch (e) {
      logger.e("Error limpiando VAD", error: e);
    }
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage("es-ES");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      logger.i("✅ TTS inicializado");
    } catch (e, stackTrace) {
      logger.e("Error inicializando TTS", error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _loadBeepSound() async {
    try {
      await _beepPlayer.setAsset(nextTurnSoundFilePath);
      logger.i("✅ Beep cargado");
    } catch (e) {
      logger.e("Error cargando beep", error: e);
    }
  }

  void _onStateChange() {
    if (!mounted) return;
    final provider = context.read<ConversationProvider>();
    
    if (provider.isConversing && (_channel == null || _isFullyDisconnected)) {
      logger.i("🚀 Iniciando nueva conversación...");
      _isFullyDisconnected = false;
      _connectAndStart();
    } else if (!provider.isConversing && _channel != null) {
      logger.i("🛑 Deteniendo conversación...");
      _disconnect();
    }
  }

  Future<void> _connectAndStart() async {
    // PASO 1: Limpiar completamente todo estado previo
    await _forceCleanupAll();
    
    final status = await Permission.microphone.request();
    if (!mounted || !status.isGranted) {
      context.read<ConversationProvider>().stopConversation();
      return;
    }

    final provider = context.read<ConversationProvider>();
    final url = "ws://$localBackendIp:8000/ws/translate_stream";

    try {
      logger.i("🔗 Conectando a WebSocket...");
      _channel = WebSocketChannel.connect(Uri.parse(url));
      await _channel!.ready;

      _webSocketSub = _channel!.stream.listen(
        _onMessageReceived,
        onError: (err) {
          logger.e("Error WebSocket", error: err);
          _disconnect();
        },
        onDone: () {
          logger.i("WebSocket cerrado");
          _disconnect();
        }
      );

      final config = {
        "event": "start",
        "source_lang": provider.sourceLang.code,
        "target_lang": provider.targetLang.code,
      };
      _channel!.sink.add(jsonEncode(config));
      logger.i("✅ WebSocket conectado y configurado");
      
      // PASO 2: Reinicializar VAD completamente
      await _reinitializeVad();
      
      // PASO 3: Iniciar ciclo
      _startListeningCycle();
    } catch (e, stackTrace) {
      logger.e("Error conectando WebSocket", error: e, stackTrace: stackTrace);
      if (mounted) provider.stopConversation();
    }
  }

  Future<void> _forceCleanupAll() async {
    logger.i("🧹 LIMPIEZA COMPLETA FORZADA...");
    
    _isProcessingTts = false;
    _vadIsListening = false;
    
    // Detener TTS
    try {
      await _flutterTts.stop();
    } catch (e) {
      logger.w("Error deteniendo TTS", error: e);
    }
    
    // Limpiar audio completamente
    await _cleanupAudioResources();
    
    // Limpiar WebSocket
    await _webSocketSub?.cancel();
    _webSocketSub = null;
    
    if (_channel != null) {
      try {
        await _channel!.sink.close();
      } catch (e) {
        logger.w("Error cerrando WebSocket", error: e);
      }
      _channel = null;
    }
    
    // Dar tiempo para que se liberen recursos
    await Future.delayed(const Duration(milliseconds: 500));
    
    logger.i("✅ Limpieza completa terminada");
  }

  Future<void> _reinitializeVad() async {
    logger.i("🔄 Reinicializando VAD completamente...");
    
    // Limpiar VAD anterior
    await _cleanupVad();
    
    // Esperar liberación de recursos
    await Future.delayed(const Duration(milliseconds: 300));
    
    // Reinicializar VAD
    await _initVad();
    
    logger.i("✅ VAD reinicializado");
  }

  Future<void> _startListeningCycle() async {
    if (!mounted || !_isInitialized || !context.read<ConversationProvider>().isConversing || _isFullyDisconnected) {
      logger.w("❌ No se puede iniciar ciclo");
      return;
    }
    
    final ctx = context.read<ConversationProvider>();
    logger.i("🎯 INICIANDO CICLO PARA: ${ctx.currentSpeaker}");

    // Limpiar recursos de audio previos
    await _cleanupAudioResources();
    _isProcessingTts = false;
    
    // Añadir mensaje temporal
    ctx.addMessage(Message(
      id: DateTime.now().toIso8601String(),
      isFromSource: ctx.currentSpeaker == 'source',
      originalText: "Escuchando...",
      translatedText: "..."
    ));

    // Delay para estabilización
    await Future.delayed(const Duration(milliseconds: 400));

    // Verificar que no se haya detenido la conversación
    if (!mounted || !context.read<ConversationProvider>().isConversing || _isFullyDisconnected) {
      return;
    }

    // Iniciar grabación continua
    await _startContinuousRecording();
    
    // Delay antes de iniciar VAD
    await Future.delayed(const Duration(milliseconds: 300));
    
    // INICIAR VAD PARA ESTE TURNO
    if (mounted && context.read<ConversationProvider>().isConversing && !_isFullyDisconnected) {
      await _startVadForTurn();
    }
  }

  Future<void> _startVadForTurn() async {
    try {
      if (_vad != null && !_vadIsListening && !_isFullyDisconnected) {
        await _vad!.startListening();
        _vadIsListening = true;
        logger.i("✅ VAD iniciado para turno actual");
      }
    } catch (e) {
      logger.e("Error iniciando VAD", error: e);
    }
  }

  Future<void> _stopVadForTurn() async {
    try {
      if (_vad != null && _vadIsListening) {
        await _vad!.stopListening();
        _vadIsListening = false;
        logger.i("🛑 VAD detenido para turno completado");
      }
    } catch (e) {
      logger.e("Error deteniendo VAD", error: e);
    }
  }

  Future<void> _startContinuousRecording() async {
    const recordConfig = RecordConfig(
      encoder: AudioEncoder.pcm16bits, 
      sampleRate: 16000, 
      numChannels: 1,
    );
    
    try {
      // FORZAR cierre de grabación previa con más tiempo
      bool wasRecording = await _audioRecorder.isRecording();
      if (wasRecording) {
        logger.w("🛑 FORZANDO cierre de grabación previa...");
        await _audioRecorder.stop();
        
        // Esperar más tiempo para asegurar liberación completa
        await Future.delayed(const Duration(milliseconds: 800));
        
        // Verificar nuevamente
        if (await _audioRecorder.isRecording()) {
          logger.e("❌ No se pudo detener grabación previa");
          return;
        }
      }
      
      // Verificar estado antes de iniciar
      if (_isFullyDisconnected || !mounted || !context.read<ConversationProvider>().isConversing) {
        logger.w("❌ Conversación detenida, no iniciar grabación");
        return;
      }
      
      logger.i("🎙️ Iniciando NUEVA grabación de audio...");
      
      // Iniciar stream de audio
      final audioStream = await _audioRecorder.startStream(recordConfig);
      _audioStreamSub = audioStream.listen(
        (data) {
          if (_channel != null && data.isNotEmpty && mounted && _vadIsListening && !_isFullyDisconnected) {
            _channel!.sink.add(data);
          }
        },
        onError: (err) {
          if (!_isFullyDisconnected) {
            logger.e("❌ Error en stream de audio", error: err);
          }
        },
        onDone: () {
          if (!_isFullyDisconnected) {
            logger.i("🏁 Stream de audio terminado");
          }
        }
      );
      
      logger.i("✅ Grabación continua iniciada correctamente");
      
    } catch (e, stackTrace) {
      logger.e("❌ Error iniciando grabación", error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _cleanupAudioResources() async {
    try {
      logger.i("🧹 Limpiando recursos de audio...");
      
      // DETENER VAD PRIMERO
      await _stopVadForTurn();
      
      // Cancelar stream subscription
      if (_audioStreamSub != null) {
        await _audioStreamSub!.cancel();
        _audioStreamSub = null;
        logger.d("✅ Stream subscription cancelado");
      }
      
      // Detener grabación con verificación extra
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
        logger.d("✅ Grabación detenida");
        
        // Esperar para asegurar liberación
        await Future.delayed(const Duration(milliseconds: 200));
      }
      
      logger.i("🧹 Recursos de audio limpiados");
      
    } catch (e) {
      logger.e("❌ Error limpiando recursos", error: e);
    }
  }

  Future<void> _onSpeechEndDetected() async {
    if (!mounted || !context.read<ConversationProvider>().isConversing || _isProcessingTts || _isFullyDisconnected) {
      return;
    }
    
    logger.i("⏹️ Procesando fin de habla...");
    
    // DETENER VAD INMEDIATAMENTE
    await _stopVadForTurn();
    
    // Esperar el tiempo de silencio configurado
    final silenceDuration = context.read<ConversationProvider>().silenceDuration;
    await Future.delayed(Duration(milliseconds: (silenceDuration * 1000).round()));
    
    if (!mounted || !context.read<ConversationProvider>().isConversing || _isFullyDisconnected) return;

    // Detener grabación
    await _cleanupAudioResources();
    context.read<ConversationProvider>().setProcessing();
    
    // Enviar señal de fin de habla al backend
    if (_channel != null && !_isFullyDisconnected) {
      _channel!.sink.add(jsonEncode({"event": "end_of_speech"}));
      logger.i("📤 Señal 'end_of_speech' enviada");
    }
  }

  void _onMessageReceived(dynamic message) {
    if (!mounted || !_isInitialized || _isFullyDisconnected) return;
    
    try {
      final data = jsonDecode(message);
      final provider = context.read<ConversationProvider>();
      
      logger.i("📨 Mensaje: ${data['type']}");
      
      switch (data['type']) {
        case 'final_translation':
          final originalText = data['original_text'] ?? '';
          final translatedText = data['translated_text'] ?? '';
          
          if (originalText.isNotEmpty && translatedText.isNotEmpty) {
            logger.i("✅ Traducción: '$originalText' -> '$translatedText'");
            provider.updateLastMessage(
              originalText: originalText,
              translatedText: translatedText
            );
            _speakTextAndProceed(translatedText);
          } else {
            logger.w("❌ Traducción vacía");
            provider.removeLastMessage();
            _startListeningCycle();
          }
          break;
        
        case 'no_speech_detected':
          logger.w("❌ No se detectó habla válida");
          provider.removeLastMessage();
          _startListeningCycle();
          break;
          
        default:
          logger.w("❓ Mensaje desconocido: ${data['type']}");
          provider.removeLastMessage();
          _startListeningCycle();
      }
    } catch (e, stackTrace) {
      logger.e("Error procesando mensaje", error: e, stackTrace: stackTrace);
      context.read<ConversationProvider>().removeLastMessage();
      _startListeningCycle();
    }
  }

  Future<void> _speakTextAndProceed(String textToSpeak) async {
    if (!mounted || !_isInitialized || textToSpeak.trim().isEmpty || _isFullyDisconnected) {
      _nextTurn();
      return;
    }
    
    logger.i("🔊 TTS: '$textToSpeak'");
    _isProcessingTts = true;
    
    final provider = context.read<ConversationProvider>();
    final targetLang = provider.currentSpeaker == 'source' 
        ? provider.targetLang.code 
        : provider.sourceLang.code;

    try {
      await _flutterTts.setLanguage(targetLang);
      await _flutterTts.speak(textToSpeak);
      await _flutterTts.awaitSpeakCompletion(true);

      logger.i("✅ TTS completado");
    } catch (e, stackTrace) {
      logger.e("Error en TTS", error: e, stackTrace: stackTrace);
    }
    
    _isProcessingTts = false;
    
    if (mounted && context.read<ConversationProvider>().isConversing && !_isFullyDisconnected) {
      _nextTurn();
    }
  }

  Future<void> _nextTurn() async {
    if (!mounted || !context.read<ConversationProvider>().isConversing || _isFullyDisconnected) return;
    
    logger.i("🔄 CAMBIANDO TURNO");
    
    // Reproducir beep
    try {
      await _beepPlayer.seek(Duration.zero);
      _beepPlayer.play();
      logger.i("🔔 Beep reproducido");
    } catch (e) {
      logger.w("Error beep", error: e);
    }
    
    // Esperar
    await Future.delayed(const Duration(milliseconds: 1000));
    
    if (!mounted || !context.read<ConversationProvider>().isConversing || _isFullyDisconnected) return;
    
    // Cambiar turno
    context.read<ConversationProvider>().switchTurn();
    logger.i("✅ Turno cambiado");
    
    // Esperar un poco más
    await Future.delayed(const Duration(milliseconds: 500));
    
    // INICIAR NUEVO CICLO
    if (mounted && context.read<ConversationProvider>().isConversing && !_isFullyDisconnected) {
      logger.i("🔄 Iniciando nuevo ciclo de escucha...");
      _startListeningCycle();
    }
  }

  Future<void> _disconnect() async {
    logger.i("🔌 Desconectando COMPLETAMENTE...");
    
    _isFullyDisconnected = true;
    _isProcessingTts = false;
    _vadIsListening = false;
    
    // Detener TTS
    try {
      await _flutterTts.stop();
    } catch (e) {
      logger.w("Error deteniendo TTS", error: e);
    }
    
    // Limpiar todos los recursos
    await _cleanupAudioResources();
    await _cleanupVad();
    
    // Limpiar WebSocket
    await _webSocketSub?.cancel();
    _webSocketSub = null;
    
    if (_channel != null) {
      try {
        await _channel!.sink.close();
      } catch (e) {
        logger.w("Error cerrando WebSocket", error: e);
      }
      _channel = null;
    }

    if (mounted) {
      final provider = context.read<ConversationProvider>();
      if (provider.isConversing) {
        provider.stopConversation();
      }
    }
    
    logger.i("✅ Desconectado COMPLETAMENTE");
  }

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              decoration: BoxDecoration(
                color: Colors.transparent,
              ),
              child: ConversationHistoryView(),
            ),
          ),
          // Controles (abajo) - eliminamos StatusIndicator completamente
          Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SettingsControls(),
          ),
        ],
      ),
    );
  }
}