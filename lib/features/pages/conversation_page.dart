// lib/features/conversation/pages/conversation_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../core/models/conversation_message.dart';
import '../../../core/providers/conversation_provider.dart';
import '../widgets/control_button.dart';
import '../widgets/conversation_history.dart';
import '../widgets/language_selector.dart';
import '../widgets/turn_indicator.dart';

// --- CONFIGURACIÓN ---
const bool USE_SIMULATED_BACKEND = false; // Asegúrate de que esto es false
const String REAL_WEBSOCKET_BASE_URL = "wss://hawerx-flowio-backend.hf.space/ws"; // ¡PON TU URL REAL AQUÍ!

class ConversationPage extends StatefulWidget {
  const ConversationPage({super.key});
  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamChannel<dynamic>? _channel;
  StreamSubscription? _webSocketSub;
  StreamSubscription<List<int>>? _audioStreamSubscription;

  @override
  void initState() {
    super.initState();
    context.read<ConversationProvider>().addListener(_handleConversationStateChange);
  }

  void _handleConversationStateChange() {
    final provider = context.read<ConversationProvider>();
    if (provider.isConversing && _channel == null) {
      _startConversation();
    } else if (!provider.isConversing && _channel != null) {
      _stopConversation();
    }
  }

  Future<void> _startConversation() async {
    final provider = context.read<ConversationProvider>();
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Se necesita permiso del micrófono para continuar.'),
        ));
      }
      provider.toggleConversation();
      return;
    }

    if (USE_SIMULATED_BACKEND) {
      _runWebSocketSimulation();
    } else {
      final url = '$REAL_WEBSOCKET_BASE_URL?target_lang=${provider.targetLanguage.code}';
      _connectToRealWebSocket(url);
    }

    _startRecording();
    provider.setStatus(listening: true, translating: false);
    provider.setTurnIndicator('user');
  }

  Future<void> _stopConversation() async {
    _webSocketSub?.cancel();
    _channel?.sink.close();
    await _stopRecording();
    if (mounted) {
      final provider = context.read<ConversationProvider>();
      provider.setStatus(listening: false, translating: false);
      provider.setTurnIndicator('none');
    }
    _channel = null;
  }

  void _connectToRealWebSocket(String url) {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _webSocketSub = _channel!.stream.listen(
        _handleWebSocketMessage,
        onError: (error) => _stopConversation(),
        onDone: () {
          if (mounted && context.read<ConversationProvider>().isConversing) {
            _stopConversation();
          }
        },
      );
    } catch (e) {
      _stopConversation();
    }
  }

  void _runWebSocketSimulation() {
    final provider = context.read<ConversationProvider>();
    int messageCounter = 0;
    final clientToServer = StreamController<dynamic>();
    final serverToClient = StreamController<dynamic>();
    _channel = StreamChannel<dynamic>(serverToClient.stream, clientToServer.sink);
    _webSocketSub = _channel!.stream.listen(_handleWebSocketMessage);

    clientToServer.stream.listen((data) {
      provider.setStatus(listening: false, translating: true);
      provider.setTurnIndicator('bot');
      final speakerId = 'USER_${messageCounter % 2}';
      provider.addMessage(ConversationMessage(id: DateTime.now().toIso8601String(), speakerId: speakerId, isTranslating: true));
      Future.delayed(const Duration(milliseconds: 800), () => provider.updateLastMessage(originalText: 'Esto es una transcripción simulada #${++messageCounter}.'));
      Future.delayed(const Duration(seconds: 2), () {
        provider.updateLastMessage(translatedText: 'This is a simulated translation #$messageCounter.', isTranslating: false);
        serverToClient.sink.add(jsonEncode({'type': 'audio_output', 'audioData': 'SIMULATED'}));
      });
    });
  }

  void _handleWebSocketMessage(dynamic message) async {
    if (!mounted) return;
    final provider = context.read<ConversationProvider>();
    final data = jsonDecode(message);
    switch (data['type']) {
      case 'processing_start':
        provider.setStatus(listening: false, translating: true);
        provider.setTurnIndicator('bot');
        provider.addMessage(ConversationMessage(id: DateTime.now().toIso8601String(), speakerId: data['speakerId'], isTranslating: true));
        break;
      case 'transcription_update':
        provider.updateLastMessage(originalText: data['originalText']);
        break;
      case 'translation_update':
        provider.updateLastMessage(translatedText: data['translatedText'], isTranslating: false);
        break;
      case 'audio_output':
        if (!USE_SIMULATED_BACKEND) {
          final audioBytes = base64Decode(data['audioData']);
          await _audioPlayer.setAudioSource(BytesAudioSource(audioBytes));
          await _audioPlayer.play();
        }
        final duration = await _audioPlayer.load() ?? const Duration(seconds: 2);
        Future.delayed(duration, () {
          if (mounted) {
            provider.setStatus(listening: true, translating: false);
            provider.setTurnIndicator('user');
          }
        });
        break;
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        // --- CAMBIO CLAVE: Especificar 1 canal (mono) y la frecuencia de muestreo ---
        const recordConfig = RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000, // Whisper funciona mejor con 16000Hz
          numChannels: 1, // Grabar en MONO
        );
        
        final stream = await _audioRecorder.startStream(recordConfig);

        _audioStreamSubscription = stream.listen((data) {
          if (_channel != null && data.isNotEmpty) {
            final payload = jsonEncode({
              "type": "audio_chunk",
              "data": base64Encode(data),
              "sample_rate": recordConfig.sampleRate, // Enviar la misma frecuencia
            });
            _channel!.sink.add(payload);
          }
        });
      }
    } catch (e) {
      print("EXCEPCIÓN en _startRecording: $e");
    }
  }

  Future<void> _stopRecording() async {
    await _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;
    if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
    }
  }

  @override
  void dispose() {
    context.read<ConversationProvider>().removeListener(_handleConversationStateChange);
    _stopConversation();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Traductor Conversacional'), centerTitle: true),
      body: Stack(
        children: [
          Column(
            children: [
              LanguageSelector(),
              const Divider(height: 1),
              Expanded(child: ConversationHistory()),
              ControlButton(),
            ],
          ),
          TurnIndicator(),
        ],
      ),
    );
  }
}

class BytesAudioSource extends StreamAudioSource {
  final List<int> bytes;
  BytesAudioSource(this.bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= bytes.length;
    return StreamAudioResponse(
        sourceLength: bytes.length,
        contentLength: end - start,
        offset: start,
        stream: Stream.value(bytes.sublist(start, end)),
        contentType: 'audio/wav');
  }
}