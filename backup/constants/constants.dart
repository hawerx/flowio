class Constants {
           
// ===========================================================
//  [IMPORTANT!] INITIAL CONFIGURATION FOR BACKEND CONNECTION
// ===========================================================

  static const bool   useLocalBackend = true;                                                   // Flag to use local backend or Huggin Face
  static const String localBackendIp  = "192.168.2.108";                                       // IPv4 address for local backend                   
  static const String hfBackendUrl    = "wss://hawerx-flowio-backend.hf.space/ws/translate";  // Hugging Face backend URL

// ===========================================================
//                WEBSocket CONFIGURATION
// ===========================================================

  static const String wsStartEvent        = "start";                                   
  static const String wsEndOfSpeechEvent  = "end_of_speech";
  static const String wsEndpoint          = "/ws/translate_stream";                             
  static String get   wsUrl               => useLocalBackend ? "ws://$localBackendIp:8000$wsEndpoint" : hfBackendUrl;

// ===========================================================
//                [IMPORTANT!] ASSET PATHS 
// ===========================================================

  static const String assetNextTurnSound  = "assets/sounds/beep.mp3";

// ===========================================================
//                    AUDIO SETTTINGS
// ===========================================================

  static const int sampleRate = 16000;
  static const int numChannels = 1;

// ===========================================================
//                    TTS SETTINGS
// ===========================================================

  static const double ttsDefaultSpeechRate  = 0.5;
  static const double ttsDefaultVolume      = 1.0;
  static const double ttsDefaultPitch       = 1.0;
}

// ===========================================================
//                    TIME DELAYS FUNCTION
// ===========================================================
  // Just a Future.delayed wrapper
  Future<dynamic> delay (int millisecs) async => Future.delayed(Duration(milliseconds: millisecs ));