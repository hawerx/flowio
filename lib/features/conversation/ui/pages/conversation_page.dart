import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vad/vad.dart'; // <-- Importar el paquete VAD
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
import '../widgets/status_indicator.dart';
import '../../../../core/models/message.dart';


// [IMPORTANT!] INITIAL CONFIGURATION FOR BACKEND CONNECTION
const bool    useLocalBackend       = true; 
const String  localBackendIp        = "192.168.2.108";
const String  hfBackendUrl          = "wss://TU-USUARIO-TU-SPACE.hf.space/ws/translate";

// [IMPORTANT!] INITIAL CONFIG FOR ASSET PATHS
const String  nextTurnSoundFilePath = "assets/sounds/beep.mp3"; 

class ConversationPage extends StatefulWidget {
  const ConversationPage({super.key});

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _beepPlayer = AudioPlayer();


  VadHandlerBase? _vad;
  WebSocketChannel? _channel;
  StreamSubscription? _webSocketSub;
  StreamSubscription<List<int>>? _audioStreamSub;

  // Streams para los eventos del VAD, para evitar anidarlos
  StreamSubscription? _onSpeechStartSub;
  StreamSubscription? _onSpeechEndSub;

  @override
  void initState() {
    super.initState();
    _initVad();
    context.read<ConversationProvider>().addListener(_onStateChange);
    _setupTts();
    _loadBeepSound();
    logger.i("ConversationPage inicializada.");
  }

  Future<void> _initVad() async {
    try {
      _vad = VadHandler.create(isDebug: true);
      // Setteamos los listeners
      _onSpeechStartSub = _vad?.onRealSpeechStart.listen((_) {
        _onSpeechStartDetected();
      });
       _onSpeechEndSub = _vad?.onSpeechEnd.listen((_) {
        _onSpeechEndDetected();
      });

      logger.i("VAD configurado correctamente.");
    } catch (e, stackTrace) {
      logger.e("Error al configurar VAD.", error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _setupTts() async {
    _flutterTts.setCompletionHandler(() {
      logger.i("TTS completado. Procediendo al siguiente turno.");
      _nextTurn();
    });
  }

  Future<void> _loadBeepSound() async {
    try {
      await _beepPlayer.setAsset(nextTurnSoundFilePath);
      logger.i("Sonido 'beep.mp3' cargado correctamente.");
    } catch (e) {
      logger.e("No se pudo cargar 'beep.mp3'. Asegúrate de que el archivo existe en assets/sounds/", error: e);
    }
  }

  void _onStateChange() {
    if (!mounted) return;
    final provider = context.read<ConversationProvider>();
    logger.d("Cambio de estado detectado. isConversing: ${provider.isConversing}, _channel: ${_channel == null ? 'nulo' : 'activo'}");
    if (provider.isConversing && _channel == null) {
      _connectAndStart();
    } else if (!provider.isConversing && _channel != null) {
      _disconnect();
    }
  }
  
  Future<void> _connectAndStart() async {
    logger.i("Solicitando permiso de micrófono...");
    final status = await Permission.microphone.request();
    if (!mounted) return;
    if (!status.isGranted) {
      logger.w("Permiso de micrófono denegado.");
      context.read<ConversationProvider>().stopConversation();
      return;
    }
    logger.i("Permiso de micrófono concedido.");
    
    final provider = context.read<ConversationProvider>();
    final url = useLocalBackend ? "ws://$localBackendIp:8000/ws/translate_stream" : hfBackendUrl;

    try {
      logger.i("Conectando a WebSocket: $url");
      _channel = WebSocketChannel.connect(Uri.parse(url));
      await _channel!.ready;
      logger.i("Conexión WebSocket establecida.");

      _webSocketSub = _channel!.stream.listen(_onMessageReceived, 
        onError: (err, stackTrace) {
          logger.e("Error en el stream del WebSocket.", error: err, stackTrace: stackTrace);
          _disconnect();
        }, 
        onDone: () {
          logger.i("Stream del WebSocket finalizado (onDone).");
          _disconnect();
        }
      );

      final config = {
        "event": "start",
        "source_lang": provider.sourceLang.code,
        "target_lang": provider.targetLang.code,
      };
      logger.i("Enviando configuración inicial al backend: ${jsonEncode(config)}");
      _channel!.sink.add(jsonEncode(config));
      
      _startListeningCycle();
    } catch (e, stackTrace) {
      logger.e("Fallo al conectar o configurar el WebSocket.", error: e, stackTrace: stackTrace);
      if (mounted) provider.stopConversation();
    }
  }
  
  Future<void> _disconnect() async {
    logger.i("Iniciando proceso de desconexión...");

    await _vad?.stopListening();
    _onSpeechStartSub?.cancel();
    _onSpeechEndSub?.cancel();
    logger.d("VAD detenido.");

    await _audioStreamSub?.cancel();
    logger.d("Suscripción al stream de audio cancelada.");

    if (await _audioRecorder.isRecording()) {
      await _audioRecorder.stop();
      logger.d("Grabación de audio detenida.");
    }
    
    _webSocketSub?.cancel();
    logger.d("Suscripción a WebSocket cancelada.");
    _channel?.sink.close();
    logger.d("Sink de WebSocket cerrado.");
    _flutterTts.stop();
    logger.d("TTS detenido.");

    if(mounted && context.read<ConversationProvider>().isConversing) {
        logger.w("La conversación seguía activa, forzando detención en el provider.");
        context.read<ConversationProvider>().stopConversation();
    }
    _channel = null;
    logger.i("Desconexión completada.");
  }

  Future<void> _startListeningCycle() async {
    if (!mounted || !context.read<ConversationProvider>().isConversing) return;
    
    final ctx = context.read<ConversationProvider>();

    logger.i("Iniciando ciclo de escucha para: ${ctx.currentSpeaker}");
    
    // Añadimos un mensaje temporal al historial que se actualizará con la respuesta
    ctx.addMessage(Message(
      id: DateTime.now().toIso8601String(),
      isFromSource: ctx.currentSpeaker == 'source',
      originalText: "Procesando...",
      translatedText: "..."
    ));
  
    // Simplemente empezamos a escuchar con el VAD. Los listeners ya están activos.
    _vad?.startListening();
  }

  Future<void> _onSpeechStartDetected() async {
    
    if (!mounted || !(context.read<ConversationProvider>().isListening)) return;

    logger.d("VAD detectó inicio de habla. Iniciando grabación de audio...");
    
    const recordConfig = RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 16000, numChannels: 1);
    
    await _audioRecorder.stop();
    await _audioStreamSub?.cancel();

    _audioStreamSub = (await _audioRecorder.startStream(recordConfig)).listen(
      (data) {
        if (_channel != null && data.isNotEmpty) {
          String audioBase64 = base64Encode(data);
          String jsonData = jsonEncode({"audio_data": audioBase64});
          _channel!.sink.add(jsonData);
        }
      },
      onError: (err, stackTrace) => logger.e("Error en stream de grabación.", error: err, stackTrace: stackTrace)
    );
  }
  
  Future<void> _onSpeechEndDetected() async {

     if (!mounted || context.read<ConversationProvider>().isProcessing) return;
    
    // Para evitar múltiples llamadas, cancelamos la suscripción de audio inmediatamente
    logger.d("VAD detectó fin de habla.");

    await _audioRecorder.stop();
    await _audioStreamSub?.cancel();
    _audioStreamSub = null;
    //await _vad?.stopListening();
    
    // No detenemos el VAD aquí, solo la grabación de audio.
    // El VAD sigue escuchando por si hay más turnos.

    if (!context.read<ConversationProvider>().isConversing) return;

    context.read<ConversationProvider>().setProcessing();
    _channel?.sink.add(jsonEncode({"event": "end_of_speech"}));
     
  }
  
  void _onMessageReceived(dynamic message) {
    if (!mounted) return;
    logger.i("Mensaje recibido del backend: $message");
    final data = jsonDecode(message);
    final provider = context.read<ConversationProvider>();
    
    switch (data['type']) {
      case 'final_translation':
        provider.updateLastMessage(
          originalText: data['original_text'],
          translatedText: data['translated_text']
        );
        _speakTextAndProceed(data['translated_text']);
        break;
      
      case 'no_speech_detected':
        logger.i("Backend no detectó habla. Eliminando mensaje temporal y pasando turno.");
        provider.removeLastMessage();
        _nextTurn();
        break;

      default:
        logger.w("Mensaje de tipo desconocido recibido: ${data['type']}");
        _nextTurn();
    }
  }

  Future<void> _speakTextAndProceed(String textToSpeak) async {
    if (!mounted) return;
    final provider = context.read<ConversationProvider>();
    final targetLang = provider.currentSpeaker == 'source' ? provider.targetLang.code : provider.sourceLang.code;
    logger.i("Iniciando TTS para el texto: '$textToSpeak' en idioma '$targetLang'");
    try {
        await _flutterTts.setLanguage(targetLang);
        await _flutterTts.speak(textToSpeak);
    } catch(e, stackTrace) {
        logger.e("Error al ejecutar TTS. Saltando al siguiente turno.", error: e, stackTrace: stackTrace);
        _nextTurn(); // Si el TTS falla, pasamos al siguiente turno igualmente
    }
  }

  Future<void> _nextTurn() async {
    if (!mounted || !context.read<ConversationProvider>().isConversing) {
      logger.w("Se intentó pasar al siguiente turno, pero la conversación ya no está activa. Abortando.");
      return;
    }
    
    logger.i("Reproduciendo sonido de cambio de turno.");
    try {
      await _beepPlayer.seek(Duration.zero);
      await _beepPlayer.play();
      // Espera a que el beep termine de sonar
      await _beepPlayer.playerStateStream.firstWhere((s) => s.processingState == ProcessingState.completed);
      logger.d("Sonido de cambio de turno finalizado.");
    } catch (e, stackTrace) {
      logger.e("Error al reproducir el sonido de beep.", error: e, stackTrace: stackTrace);
    }

    if (!mounted) return;
    context.read<ConversationProvider>().switchTurn();
    _startListeningCycle();
  }

  @override
  void dispose() {
    logger.i("Realizando limpieza de Conversation Page...");
    _onSpeechStartSub?.cancel();
    _onSpeechEndSub?.cancel();
    _disconnect();
    _vad?.dispose();
    _beepPlayer.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Flowio Translator")),
      body: Column(
        children: [
          const SettingsControls(),
          const Divider(height: 1),
          const StatusIndicator(),
          const Divider(height: 1),
          Expanded(child: ConversationHistoryView()),
        ],
      ),
    );
  }
}