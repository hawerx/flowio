import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

// Creamos una instancia global del logger para poder usarla en cualquier parte de la app.
final logger = Logger(
  // Usamos PrettyPrinter para un formato de log bonito, con colores y stack traces.
  printer: PrettyPrinter(
    methodCount: 1, // Cuántos métodos de la pila de llamadas mostrar
    errorMethodCount: 5, // Cuántos métodos mostrar en caso de error
    lineLength: 80, // Ancho de la línea
    colors: true, // Logs con colores
    printEmojis: true, // Emojis para cada nivel de log
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart  // Shows only time and since app start
  ),
  // Establecemos el nivel de log. En modo debug, muestra todo.
  // En modo release (producción), no muestra nada (level: Level.off).
  level: kDebugMode ? Level.debug : Level.off,
);