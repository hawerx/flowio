// ignore_for_file: constant_identifier_names

class Constants {
           
// ===========================================================
//  [IMPORTANTE!] Configuration for backend
// ===========================================================

  static const bool   USE_LOCAL_BACKEND = true;                                                    // Flag to use local backend or Huggin Face
  static const String LOCAL_BACKEND_IP  = "192.168.2.108";                                        // IPv4 address for local backend                   
  static const String HUGGING_FACE_URL  = "wss://hawerx-flowio-backend.hf.space/ws/translation"; // Hugging Face backend URL

// ===========================================================
//                WEBSocket Configuration
// ===========================================================

  static const String WS_START_EVENT          = "start";                                   
  static const String WS_END_OF_SPEECH_EVENT  = "end_of_speech";
  static const String WS_ENDPOINT             = "/ws/translation";                             
  static String get   WS_URL                  => USE_LOCAL_BACKEND ? "ws://$LOCAL_BACKEND_IP:8000$WS_ENDPOINT" : HUGGING_FACE_URL;

// ===========================================================
//                [IMPORTANT!] ASSET PATHS 
// ===========================================================

  static const String ASSET_NEXT_TURN_SOUND   = "assets/sounds/beep.mp3";

// ===========================================================
//                    AUDIO SETTINGS
// ===========================================================

  static const int AUDIO_SAMPLE_RATE = 16000;
  static const int AUDIO_NUM_CHANNELS = 1;

// ===========================================================
//                    TTS SETTINGS
// ===========================================================

  static const double TTS_DEFAULT_SPEECH_RATE = 0.5;
  static const double TTS_DEFAULT_VOLUME      = 1.0;
  static const double TTS_DEFAULT_PITCH       = 1.0;

// ===========================================================
//                    TIMING SETTINGS
// ===========================================================

  static const int DELAY_STABILIZATION_MS     = 400;
  static const int DELAY_VAD_START_MS         = 300;
  static const int DELAY_AUDIO_CLEANUP_MS     = 200;
  static const int DELAY_RESOURCE_CLEANUP_MS  = 500;
  static const int DELAY_FORCE_STOP_MS        = 800;
  static const int DELAY_TURN_CHANGE_MS       = 1000;
  static const int DELAY_NEXT_TURN_MS         = 500;
  static const int DELAY_VAD_REINIT_MS        = 300;

// ===========================================================
//                SILENCE SILIDER SETTINGS
// ===========================================================

  static const double SLIDER_MIN_VALUE      = 0.25;
  static const double SLIDER_MAX_VALUE      = 2.0;
  static const double SLIDER_DEFAULT_VALUE  = 0.5;
  static const int    SLIDER_DIVISIONS      = 7;    // 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0

// ===========================================================
//                    TIME DELAYS FUNCTION
// ===========================================================
/// Función de utilidad para delays
Future<void> delay(int millisecs) async => Future.delayed(Duration(milliseconds: millisecs));
}