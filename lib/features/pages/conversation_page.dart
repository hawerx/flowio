import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
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
const bool USE_SIMULATED_BACKEND = true;
const String REAL_WEBSOCKET_BASE_URL = "wss://tu-nombre-tu-space.hf.space/ws";

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
  Timer? _chunkSenderTimer;

  @override
  void initState() {
    super.initState();
    // Escucha los cambios en el estado de la conversación para iniciar/detener
    context.read<ConversationProvider>().addListener(
      _handleConversationStateChange,
    );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Se necesita permiso del micrófono para continuar.'),
          ),
        );
      }
      provider.toggleConversation(); // Revierte el estado si no hay permiso
      return;
    }

    if (USE_SIMULATED_BACKEND) {
      _runWebSocketSimulation();
    } else {
      final url =
          '$REAL_WEBSOCKET_BASE_URL?target_lang=${provider.targetLanguage.code}';
      _connectToRealWebSocket(url);
    }

    _startRecording();
    provider.setStatus(listening: true, translating: false);
    provider.setTurnIndicator('user');
  }

  Future<void> _stopConversation() async {
    _chunkSenderTimer?.cancel();
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
        onError: (error) {
          print("Error de WebSocket: $error");
          _stopConversation();
        },
        onDone: () {
          print("WebSocket cerrado por el servidor.");
          if (mounted && context.read<ConversationProvider>().isConversing) {
            _stopConversation();
          }
        },
      );
    } catch (e) {
      print("No se pudo conectar al WebSocket: $e");
      _stopConversation();
    }
  }

  void _runWebSocketSimulation() {
    final provider = context.read<ConversationProvider>();
    int messageCounter = 0;

    final clientToServer = StreamController<dynamic>();
    final serverToClient = StreamController<dynamic>();

    // El canal que usará el cliente: escucha del servidor y escribe al servidor
    _channel = StreamChannel<dynamic>(
      serverToClient.stream,
      clientToServer.sink,
    );
    _webSocketSub = _channel!.stream.listen(_handleWebSocketMessage);

    // La lógica de simulación (nuestro falso servidor) escucha lo que envía el cliente
    clientToServer.stream.listen((data) {
      print("Simulación: Audio recibido");
      provider.setStatus(listening: false, translating: true);
      provider.setTurnIndicator('bot');

      final speakerId = 'USER_${messageCounter % 2}';
      final message = ConversationMessage(
        id: DateTime.now().toIso8601String(),
        speakerId: speakerId,
        isTranslating: true,
      );
      provider.addMessage(message);

      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted)
          provider.updateLastMessage(
            originalText:
                'Esto es una transcripción simulada #${++messageCounter}.',
          );
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          provider.updateLastMessage(
            translatedText: 'This is a simulated translation #$messageCounter.',
            isTranslating: false,
          );
          final audioData = "SIMULATED_AUDIO_DATA";
          // El servidor simulado envía una respuesta al cliente
          serverToClient.sink.add(
            jsonEncode({'type': 'audio_output', 'audioData': audioData}),
          );
        }
      });
    });
  }

  void _handleWebSocketMessage(dynamic message) async {
    if (!mounted) return;
    final provider = context.read<ConversationProvider>();
    try {
      final data = jsonDecode(message);

      switch (data['type']) {
        case 'processing_start':
          provider.setStatus(listening: false, translating: true);
          provider.setTurnIndicator('bot');
          provider.addMessage(
            ConversationMessage(
              id: DateTime.now().toIso8601String(),
              speakerId: data['speakerId'],
              isTranslating: true,
            ),
          );
          break;
        case 'transcription_update':
          provider.updateLastMessage(originalText: data['originalText']);
          break;
        case 'translation_update':
          provider.updateLastMessage(
            translatedText: data['translatedText'],
            isTranslating: false,
          );
          break;
        case 'audio_output':
          if (!USE_SIMULATED_BACKEND) {
            final audioBytes = base64Decode(data['audioData']);
            await _audioPlayer.setAudioSource(BytesAudioSource(audioBytes));
            await _audioPlayer.play();
          } else {
            print("Simulación: Reproduciendo audio...");
          }
          final duration =
              await _audioPlayer.load() ?? const Duration(seconds: 2);
          Future.delayed(duration, () {
            if (mounted) {
              provider.setStatus(listening: true, translating: false);
              provider.setTurnIndicator('user');
            }
          });
          break;
      }
    } catch (e) {
      print("Error al procesar mensaje de WS: $e");
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        const encoder = AudioEncoder.wav;
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/temp_audio.${encoder.name}';

        await _audioRecorder.start(
          const RecordConfig(encoder: encoder),
          path: path,
        );

        _chunkSenderTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
          if (!mounted || !context.read<ConversationProvider>().isConversing) {
            timer.cancel();
            return;
          }
          _stopAndSendAudioChunk();
        });
      }
    } catch (e) {
      print("Error al iniciar la grabación: $e");
    }
  }

  Future<void> _stopAndSendAudioChunk() async {
    try {
      final path = await _audioRecorder.stop();
      if (path != null && _channel != null) {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          if (bytes.isNotEmpty) {
            _channel!.sink.add(bytes);
          }
          await file.delete();
        }

        if (mounted && context.read<ConversationProvider>().isConversing) {
          await _audioRecorder.start(
            const RecordConfig(encoder: AudioEncoder.wav),
            path: path,
          );
        }
      }
    } catch (e) {
      print("Error enviando fragmento de audio: $e");
    }
  }

  Future<void> _stopRecording() async {
    _chunkSenderTimer?.cancel();
    // No es necesario comprobar si está grabando, el método stop()
    // ya lo gestiona internamente y no hace nada si no está activo.
    // stop() devuelve un Future, así que lo esperamos.
    await _audioRecorder.stop();
  }

  @override
  void dispose() {
    context.read<ConversationProvider>().removeListener(
      _handleConversationStateChange,
    );
    _stopConversation();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Traductor Conversacional'),
        centerTitle: true,
        elevation: 1,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              LanguageSelector(),
              const Divider(height: 1, thickness: 1),
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

// Clase de ayuda para reproducir audio desde bytes
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
      contentType: 'audio/wav',
    );
  }
}
