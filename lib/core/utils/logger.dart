import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

// Instancia global del logger
final logger = Logger(
  printer: PrettyPrinter(
    methodCount:      1,
    errorMethodCount: 5, 
    lineLength:       120, 
    colors:           true, 
    printEmojis:      true,
    dateTimeFormat:   DateTimeFormat.onlyTimeAndSinceStart
  ),
  // Si la app esta en modo debug muestra mensajes
  level: kDebugMode ? Level.debug : Level.off,
);