// import 'dart:async';
// import 'dart:convert';
// import 'package:web_socket_channel/web_socket_channel.dart';
// import '../../../../core/utils/logger.dart';

// class WebSocketManager {
//   WebSocketChannel? _channel;
//   StreamSubscription? _subscription;
//   String? _url;
//   Map<String, dynamic>? _config;
  
//   bool _isConnected = false;
//   Function(dynamic)? _onMessageCallback;
//   Function()? _onErrorCallback;

//   bool get isConnected => _isConnected && _channel != null;

//   Future<void> connect({
//     required String url,
//     required Map<String, dynamic> config,
//     required Function(dynamic) onMessage,
//     Function()? onError,
//   }) async {
//     _url = url;
//     _config = config;
//     _onMessageCallback = onMessage;
//     _onErrorCallback = onError;

//     await _disconnect();
    
//     try {
//       logger.i("🔗 Conectando a WebSocket: $url");
      
//       _channel = WebSocketChannel.connect(Uri.parse(url));
//       await _channel!.ready;
      
//       _subscription = _channel!.stream.listen(
//         _onMessageReceived,
//         onError: _onWebSocketError,
//         onDone: _onWebSocketDone,
//       );
      
//       // Marcar como conectado ANTES de enviar configuración
//       _isConnected = true;
//       logger.i("✅ WebSocket conectado");
      
//       // Enviar configuración inicial
//       await send(config);  
//       logger.i("📤 Configuración inicial enviada: $config");
      
//     } catch (e, stackTrace) {
//       logger.e("❌ Error conectando WebSocket", error: e, stackTrace: stackTrace);
//       _isConnected = false;
//       _onErrorCallback?.call();
//       rethrow;
//     }
//   }

//   Future<void> send(dynamic data) async {
//     if (!isConnected) {
//       logger.w("⚠️ WebSocket no conectado, no se puede enviar");
//       return;
//     }
    
//     try {
//       if (data is Map || data is List<dynamic>) {
//         // Para mapas y listas de objetos, usar jsonEncode
//         final jsonData = jsonEncode(data);
//         _channel!.sink.add(jsonData);
//         logger.d("📤 Enviado JSON: $jsonData");
//       } else if (data is List<int>) {
//         // Para datos de audio (bytes), enviar directamente
//         _channel!.sink.add(data);
//         logger.d("📤 Enviados ${data.length} bytes de audio");
//       } else {
//         // Para otros tipos, convertir a string
//         final stringData = data.toString();
//         _channel!.sink.add(stringData);
//         logger.d("📤 Enviado String: $stringData");
//       }
//     } catch (e) {
//       logger.e("❌ Error enviando datos", error: e);
//     }
//   }

//   void _onMessageReceived(dynamic message) {
//     if (_onMessageCallback != null) {
//       _onMessageCallback!(message);
//     }
//   }

//   void _onWebSocketError(dynamic error) {
//     logger.e("❌ Error WebSocket", error: error);
//     _isConnected = false;
//     _onErrorCallback?.call();
//   }

//   void _onWebSocketDone() {
//     logger.w("⚠️ WebSocket cerrado inesperadamente");
//     _isConnected = false;
    
//     // Intentar reconectar si tenemos configuración
//     if (_url != null && _config != null && _onMessageCallback != null) {
//       logger.i("🔄 Intentando reconectar...");
//       Future.delayed(const Duration(milliseconds: 1000), () {
//         connect(
//           url: _url!,
//           config: _config!,
//           onMessage: _onMessageCallback!,
//           onError: _onErrorCallback,
//         );
//       });
//     }
//   }

//   Future<void> _disconnect() async {
//     _isConnected = false;
    
//     await _subscription?.cancel();
//     _subscription = null;
    
//     if (_channel != null) {
//       try {
//         await _channel!.sink.close();
//       } catch (e) {
//         logger.w("⚠️ Error cerrando WebSocket", error: e);
//       }
//       _channel = null;
//     }
//   }

//   Future<void> dispose() async {
//     logger.i("🧹 Limpiando WebSocketManager...");
//     await _disconnect();
//     _onMessageCallback = null;
//     _onErrorCallback = null;
//     _url = null;
//     _config = null;
//     logger.i("✅ WebSocketManager limpiado");
//   }
// }