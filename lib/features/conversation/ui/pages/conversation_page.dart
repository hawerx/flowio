import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
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

  WebSocketChannel? _channel;
  StreamSubscription? _webSocketSub;
  StreamSubscription<List<int>>? _audioStreamSub;
  Timer? _silenceTimer;

  @override
  void initState() {
    super.initState();
    context.read<ConversationProvider>().addListener(_onStateChange);
    _setupTts();
    _loadBeepSound();
  }

  Future<void> _setupTts() async {
    _flutterTts.setCompletionHandler(() => _nextTurn());
  }

  Future<void> _loadBeepSound() async {
    try {
      await _beepPlayer.setAsset(nextTurnSoundFilePath);
    } catch (e) {
      logger.e("No se pudo cargar 'beep.mp3'.", error: e);
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
    final url = useLocalBackend ? "ws://$localBackendIp:8000/ws/translate_stream" : hfBackendUrl;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      await _channel!.ready;

      _webSocketSub = _channel!.stream.listen(_onMessageReceived, onError: (err) {
        logger.e("Error de WebSocket", error: err);
        _disconnect();
      }, onDone: _disconnect);

      logger.i("Conectado a $url. Enviando configuración...");
      _channel!.sink.add(jsonEncode({
        "event": "start",
        "source_lang": provider.sourceLang.code,
        "target_lang": provider.targetLang.code,
      }));
      
      _startListeningCycle();
    } catch (e, stackTrace) {
      logger.e("Error de conexión", error: e, stackTrace: stackTrace);
      if (mounted) provider.stopConversation();
    }
  }
  
  Future<void> _disconnect() async {
    _silenceTimer?.cancel();
    await _audioStreamSub?.cancel();
    if (await _audioRecorder.isRecording()) await _audioRecorder.stop();
    _webSocketSub?.cancel();
    _channel?.sink.close();
    _flutterTts.stop();
    if(mounted && context.read<ConversationProvider>().isConversing) {
        context.read<ConversationProvider>().stopConversation();
    }
    _channel = null;
    logger.i("Desconectado.");
  }

  Future<void> _startListeningCycle() async {
    if (!mounted) return;
    final provider = context.read<ConversationProvider>();
    logger.i("Iniciando ciclo de escucha para: ${provider.currentSpeaker}");
    
    const recordConfig = RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 16000, numChannels: 1);

    if(await _audioRecorder.isRecording()) await _audioRecorder.stop();
    
    _audioStreamSub = (await _audioRecorder.startStream(recordConfig)).listen((data) {
      _channel?.sink.add(data);
      _resetSilenceTimer();
    });
    
    _resetSilenceTimer();
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    if (!mounted) return;
    final provider = context.read<ConversationProvider>();
    _silenceTimer = Timer(Duration(milliseconds: (provider.silenceDuration * 1000).toInt()), _onSilenceDetected);
  }
  
  void _onSilenceDetected() {
    if (!mounted) return;
    logger.d("Silencio detectado. Finalizando turno.");
    final provider = context.read<ConversationProvider>();
    provider.commitPartialTranscription();
    provider.setProcessing();
    _channel?.sink.add(jsonEncode({"event": "end_of_speech"}));
  }
  
  void _onMessageReceived(dynamic message) {
    if (!mounted) return;
    logger.d("Mensaje recibido: $message");
    final data = jsonDecode(message);
    final provider = context.read<ConversationProvider>();
    
    switch (data['type']) {
      case 'partial_transcription':
        provider.updatePartialTranscription(data['text']);
        break;
      case 'final_translation':
        provider.updateLastMessage(translatedText: data['translated_text']);
        _speakTextAndProceed(data['translated_text']);
        break;
    }
  }

  Future<void> _speakTextAndProceed(String textToSpeak) async {
    if (!mounted) return;
    final provider = context.read<ConversationProvider>();
    try {
        final targetLang = provider.currentSpeaker == 'source' ? provider.targetLang.code : provider.sourceLang.code;
        await _flutterTts.setLanguage(targetLang);
        await _flutterTts.speak(textToSpeak);
    } catch(e) {
        logger.e("Error en el TTS", error: e);
        _nextTurn();
    }
  }

  Future<void> _nextTurn() async {
    if (!mounted) return;
    
    await _beepPlayer.seek(Duration.zero);
    await _beepPlayer.play();
    await _beepPlayer.playerStateStream.firstWhere((s) => s.processingState == ProcessingState.completed);

    if (!mounted) return;
    context.read<ConversationProvider>().switchTurn();
    _startListeningCycle();
  }

  @override
  void dispose() {
    _disconnect();
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