import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../../core/utils/logger.dart';
import '../../providers/conversation_provider.dart';
import '../widgets/conversation_history_view.dart';
import '../widgets/settings_controls.dart';
import '../widgets/status_indicator.dart';
import '../../../../core/models/message.dart';


// --- CONFIGURACIÓN DE CONEXIÓN ---
const bool useLocalBackend = true; 
const String localBackendIp = "192.168.2.108"; // ¡PON LA IP LOCAL DE TU ORDENADOR!
const String hfBackendUrl = "wss://TU-USUARIO-TU-SPACE.hf.space/ws/translate";

class ConversationPage extends StatefulWidget {
  const ConversationPage({super.key});

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _beepPlayer = AudioPlayer();

  WebSocketChannel? _channel;
  StreamSubscription? _webSocketSub;
  StreamSubscription<Amplitude>? _amplitudeSub;
  Timer? _silenceTimer;
  final List<int> _audioBuffer = [];
  bool _hasSpeechStartedInTurn = false;

  @override
  void initState() {
    super.initState();
    context.read<ConversationProvider>().addListener(_onStateChange);
    _loadBeepSound();
  }

  Future<void> _loadBeepSound() async {
    try {
      await _beepPlayer.setAsset('assets/sounds/beep.mp3');
    } catch (e, stackTrace) {
      logger.e("No se pudo cargar 'beep.mp3'.", error: e, stackTrace: stackTrace);
    }
  }

  void _onStateChange() {
    if (!mounted) return;
    final provider = context.read<ConversationProvider>();
    if (provider.isConversing && _channel == null) {
      _connectAndStart();
    } else if (!provider.isConversing && _channel != null) {
      _disconnect();
    }
  }
  
  Future<void> _connectAndStart() async {
    final status = await Permission.microphone.request();
    if (!mounted || !status.isGranted) return;
    
    final provider = context.read<ConversationProvider>();
    final url = useLocalBackend 
        ? "ws://$localBackendIp:8000/ws/translate" 
        : hfBackendUrl;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _webSocketSub = _channel!.stream.listen(_onMessageReceived, onError: (err) {
        logger.e("Error de WebSocket", error: err);
        _disconnect();
      }, onDone: _disconnect);
      logger.i("Conectado a $url");
      _startListeningCycle();
    } catch (e, stackTrace) {
      logger.e("Error de conexión", error: e, stackTrace: stackTrace);
      if (mounted) {
        provider.stopConversation();
      }
    }
  }
  
  Future<void> _disconnect() async {
    _silenceTimer?.cancel();
    _amplitudeSub?.cancel();
    if (await _audioRecorder.isRecording()) {
      await _audioRecorder.stop();
    }
    _webSocketSub?.cancel();
    _channel?.sink.close();
    if(mounted && context.read<ConversationProvider>().isConversing){
        context.read<ConversationProvider>().stopConversation();
    }
    _channel = null;
    logger.i("Desconectado.");
  }

  Future<void> _startListeningCycle() async {
    if (!mounted) return;
    final provider = context.read<ConversationProvider>();
    logger.i("Iniciando ciclo de escucha para: ${provider.currentSpeaker}");
    _audioBuffer.clear();
    _hasSpeechStartedInTurn = false;
    
    const recordConfig = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
    );

    if(await _audioRecorder.isRecording()) {
      await _audioRecorder.stop();
    }
    await _audioRecorder.start(recordConfig, path: 'temp_audio.m4a');
    
    _amplitudeSub = _audioRecorder.onAmplitudeChanged(const Duration(milliseconds: 200)).listen((amp) {
      if (amp.current > -35) {
        if (!_hasSpeechStartedInTurn) {
          logger.d("Actividad de voz detectada.");
          _hasSpeechStartedInTurn = true;
        }
        _resetSilenceTimer();
      }
    });

    final stream = await _audioRecorder.startStream(recordConfig);
    if (!mounted) return;
    
    stream.listen((data) {
      _audioBuffer.addAll(data);
    });
    
    _resetSilenceTimer();
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    if (!mounted) return;
    final provider = context.read<ConversationProvider>();
    _silenceTimer = Timer(Duration(milliseconds: (provider.silenceDuration * 1000).toInt()), _onSilenceDetected);
  }
  
  Future<void> _onSilenceDetected() async {
    if (!mounted) return;
    final provider = context.read<ConversationProvider>();
    if (provider.isProcessing) return;
    
    await _amplitudeSub?.cancel();
    await _audioRecorder.stop();
    
    if (_hasSpeechStartedInTurn) {
      // --- LÓGICA CORREGIDA ---
      // 1. Primero, comprobamos si el audio es válido.
      if (_audioBuffer.length > 8000 && _channel != null) {
        // 2. Si es válido, AHORA cambiamos el estado a "Procesando".
        logger.d("Silencio detectado después de hablar. Procesando audio...");
        provider.setProcessing();

        final isSourceTurn = provider.currentSpeaker == 'source';
        final message = {
          "source_lang": isSourceTurn ? provider.sourceLang.code : provider.targetLang.code,
          "target_lang": isSourceTurn ? provider.targetLang.code : provider.sourceLang.code,
          "audio_data": base64Encode(_audioBuffer),
        };
        
        provider.addMessage(Message(id: DateTime.now().toIso8601String(), isFromSource: isSourceTurn));
        logger.i("Enviando audio al backend (${_audioBuffer.length} bytes)");
        _channel!.sink.add(jsonEncode(message));
      } else {
        // 3. Si no es válido, no hacemos nada y reiniciamos la escucha.
        logger.i("Audio demasiado corto. Reiniciando escucha para el mismo hablante.");
        _startListeningCycle();
      }
    } else {
      logger.i("Silencio total detectado. Reiniciando ciclo de escucha.");
      _startListeningCycle();
    }
  }
  
  void _onMessageReceived(dynamic message) {
    if (!mounted) return;
    logger.d("Mensaje recibido del backend: $message");
    final data = jsonDecode(message);
    final provider = context.read<ConversationProvider>();
    
    switch (data['type']) {
      case 'transcription':
        provider.updateLastMessage(originalText: data['text']);
        break;
      case 'translation':
        provider.updateLastMessage(
          originalText: data['original_text'],
          translatedText: data['translated_text'],
        );
        _playAudioAndProceed(data['audio_data'], switchTurn: true);
        break;
      case 'turn_end_no_tts':
        logger.i("Turno finalizado por backend (sin TTS). Volviendo a escuchar.");
        provider.removeLastMessageIfEmpty();
        _playAudioAndProceed(null, switchTurn: false);
        break;
    }
  }

  Future<void> _playAudioAndProceed(String? audioB64, {required bool switchTurn}) async {
    if (!mounted) return;
    final provider = context.read<ConversationProvider>();
    
    try {
      if (audioB64 != null) {
        await _audioPlayer.setAudioSource(BytesAudioSource(base64Decode(audioB64)));
        await _audioPlayer.play();
        await _audioPlayer.playerStateStream.firstWhere((s) => s.processingState == ProcessingState.completed);
      }
      
      if (!mounted) return;
      
      if (switchTurn) {
        await _beepPlayer.seek(Duration.zero);
        await _beepPlayer.play();
        await _beepPlayer.playerStateStream.firstWhere((s) => s.processingState == ProcessingState.completed);
      }

      if (!mounted) return;

      if (switchTurn) {
        provider.switchTurn();
      } else {
        provider.revertToListening();
      }
      _startListeningCycle();

    } catch(e, stackTrace) {
      logger.e("Error en reproducción y cambio de turno", error: e, stackTrace: stackTrace);
      if(mounted) {
        provider.revertToListening();
        _startListeningCycle();
      }
    }
  }

  @override
  void dispose() {
    _disconnect();
    _audioPlayer.dispose();
    _beepPlayer.dispose();
    _audioRecorder.dispose();
    context.read<ConversationProvider>().removeListener(_onStateChange);
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
          const Expanded(child: ConversationHistoryView()),
        ],
      ),
    );
  }
}

// Clase auxiliar para el reproductor de audio
class BytesAudioSource extends StreamAudioSource {
  final Uint8List bytes;
  BytesAudioSource(this.bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    return StreamAudioResponse(
        sourceLength: bytes.length,
        contentLength: (end ?? bytes.length) - (start ?? 0),
        offset: start ?? 0,
        stream: Stream.value(bytes.sublist(start ?? 0, end ?? bytes.length)),
        contentType: 'audio/wav');
  }
}