import 'package:just_audio/just_audio.dart';
import '../utils/logger.dart';
import '../constants/constants.dart';

/// Servicio encargado de la reproducción de sonidos
class SoundService {

  final AudioPlayer _beepPlayer = AudioPlayer();
  bool _isInitialized           = false;
  bool get isInitialized        => _isInitialized;

  /// Inicializa el servicio de sonidos
  Future<void> initialize() async {
    try {
      await _beepPlayer.setAsset(Constants.ASSET_NEXT_TURN_SOUND);
      _isInitialized = true;
      logger.i("Servicio de sonidos inicializado");
    } catch (e) {
      logger.e("Error inicializando servicio de sonidos", error: e);
    }
  }

  /// Reproduce el sonido de cambio de turno
  Future<void> playTurnChangeBeep() async {
    if (!_isInitialized) {
      logger.w("Servicio de sonidos no inicializado");
      return;
    }

    try {
      await _beepPlayer.seek(Duration.zero);
      _beepPlayer.play();
      logger.i("Beep de cambio de turno reproducido");
    } catch (e) {
      logger.w("Error reproduciendo beep", error: e);
    }
  }

  Future<void> dispose() async {
    try {
      await _beepPlayer.dispose();
      _isInitialized = false;
    } catch (e) {
      logger.w("Error eliminando servicio de sonidos", error: e);
    }
  }
}
