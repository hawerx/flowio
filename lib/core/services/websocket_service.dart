import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../utils/logger.dart';
import '../constants/constants.dart';

/// Estados de conexión del WebSocket
enum WebSocketState {
  disconnected,
  connecting,
  connected,
  error
}

/// Modelo para configuración del WebSocket
class WebSocketConfig {
  final String sourceLanguage;
  final String targetLanguage;

  WebSocketConfig({
    required this.sourceLanguage,
    required this.targetLanguage,
  });

  Map<String, dynamic> toJson() => {
    "event": Constants.WS_START_EVENT,
    "source_lang": sourceLanguage,
    "target_lang": targetLanguage,
  };
}

/// Servicio encargado de la comunicación WebSocket
class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _webSocketSub;
  WebSocketState _currentState = WebSocketState.disconnected;

  /// Callbacks para eventos de WebSocket
  Function(Map<String, dynamic>)? onMessageReceived;
  Function(dynamic)? onError;
  Function()? onDisconnected;

  WebSocketState get currentState => _currentState;
  bool get isConnected => _currentState == WebSocketState.connected;

  /// Conecta al WebSocket con la configuración especificada
  Future<bool> connect(WebSocketConfig config) async {
    try {
      _currentState = WebSocketState.connecting;
      logger.i("Conectando a WebSocket...");

      _channel = WebSocketChannel.connect(Uri.parse(Constants.WS_URL));
      await _channel!.ready;

      _webSocketSub = _channel!.stream.listen(
        _handleMessage,
        onError: (err) {
          logger.e("Error WebSocket", error: err);
          _currentState = WebSocketState.error;
          onError?.call(err);
          disconnect();
        },
        onDone: () {
          logger.i("Conexión con el WebSocket cerrada");
          _currentState = WebSocketState.disconnected;
          onDisconnected?.call();
        }
      );

      // Enviar configuración inicial
      _channel!.sink.add(jsonEncode(config.toJson()));
      _currentState = WebSocketState.connected;
      logger.i("WebSocket conectado y configurado");
      return true;
    } catch (e, stackTrace) {
      logger.e("Error conectando WebSocket", error: e, stackTrace: stackTrace);
      _currentState = WebSocketState.error;
      return false;
    }
  }

  /// Envía datos de audio al WebSocket
  void sendAudioData(List<int> completeAudio) {
    if (_channel != null && _currentState == WebSocketState.connected && completeAudio.isNotEmpty) {
      _channel!.sink.add(completeAudio);
      logger.i("Audio completo enviado: ${completeAudio.length} samples");
    }
  }

  /// Envía el evento de end of speech al WebSocket
  void sendEndOfSpeechEvent() {
    if (_channel != null && _currentState == WebSocketState.connected) {
      _channel!.sink.add(jsonEncode({"event": Constants.WS_END_OF_SPEECH_EVENT}));
      logger.i("Señal 'end_of_speech' enviada");
    }
  }

  /// Maneja los mensajes recibidos del WebSocket
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      logger.i("Mensaje: ${data['type']}");
      onMessageReceived?.call(data);
    } catch (e, stackTrace) {
      logger.e("Error procesando mensaje WebSocket", error: e, stackTrace: stackTrace);
    }
  }

  /// Desconecta el WebSocket
  Future<void> disconnect() async {
    try {
      logger.i("Desconectando WebSocket...");
      
      await _webSocketSub?.cancel();
      _webSocketSub = null;
      
      if (_channel != null) {
        await _channel!.sink.close();
        _channel = null;
      }
      
      _currentState = WebSocketState.disconnected;
      logger.i("WebSocket desconectado");
    } catch (e) {
      logger.w("Error desconectando WebSocket", error: e);
    }
  }

  Future<void> dispose() async {
    await disconnect();
  }
}
