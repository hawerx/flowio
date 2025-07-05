import '../models/language.dart';

/// Constantes de idiomas soportados por la aplicación Flowio
/// 
/// Esta clase contiene todos los idiomas disponibles para traducción
/// en una lista unificada y alfabéticamente ordenada.
class LanguageConstants {
  
  // ===========================================================
  //                  TODOS LOS IDIOMAS SOPORTADOS
  // ===========================================================
  
  /// Lista completa de todos los idiomas soportados, ordenados alfabéticamente
  static const List<Language> allSupportedLanguages = [
    Language('af', 'Afrikáans'),
    Language('am', 'Amhárico'),
    Language('ar', 'Árabe'),
    Language('bn', 'Bengalí'),
    Language('bg', 'Búlgaro'),
    Language('zh', 'Chino (Mandarín)'),
    Language('ko', 'Coreano'),
    Language('hr', 'Croata'),
    Language('cs', 'Checo'),
    Language('da', 'Danés'),
    Language('de', 'Alemán'),
    Language('sk', 'Eslovaco'),
    Language('sl', 'Esloveno'),
    Language('es', 'Español'),
    Language('es-AR', 'Español (Argentina)'),
    Language('es-MX', 'Español (México)'),
    Language('et', 'Estonio'),
    Language('tl', 'Filipino'),
    Language('fi', 'Finlandés'),
    Language('fr', 'Francés'),
    Language('fr-CA', 'Francés (Canadá)'),
    Language('el', 'Griego'),
    Language('gu', 'Gujarati'),
    Language('ha', 'Hausa'),
    Language('he', 'Hebreo'),
    Language('hi', 'Hindi'),
    Language('nl', 'Holandés'),
    Language('hu', 'Húngaro'),
    Language('ig', 'Igbo'),
    Language('id', 'Indonesio'),
    Language('en', 'Inglés'),
    Language('it', 'Italiano'),
    Language('ja', 'Japonés'),
    Language('kn', 'Kannada'),
    Language('lv', 'Letón'),
    Language('lt', 'Lituano'),
    Language('ms', 'Malayo'),
    Language('ml', 'Malayalam'),
    Language('mr', 'Marathi'),
    Language('no', 'Noruego'),
    Language('pa', 'Punjabi'),
    Language('fa', 'Persa'),
    Language('pl', 'Polaco'),
    Language('pt', 'Portugués'),
    Language('pt-BR', 'Portugués (Brasil)'),
    Language('ro', 'Rumano'),
    Language('ru', 'Ruso'),
    Language('sv', 'Sueco'),
    Language('sw', 'Swahili'),
    Language('th', 'Tailandés'),
    Language('ta', 'Tamil'),
    Language('te', 'Telugu'),
    Language('tr', 'Turco'),
    Language('ur', 'Urdu'),
    Language('vi', 'Vietnamita'),
    Language('yo', 'Yoruba'),
    Language('zu', 'Zulú'),
  ];

  // ===========================================================
  //                  CONFIGURACIÓN POR DEFECTO
  // ===========================================================
  
  /// Idioma por defecto para el hablante fuente
  static const Language defaultSourceLanguage = Language('es', 'Español');
  
  /// Idioma por defecto para el hablante destino
  static const Language defaultTargetLanguage = Language('en', 'Inglés');

  // ===========================================================
  //                  MÉTODOS DE UTILIDAD
  // ===========================================================
  
  /// Encuentra un idioma por su código
  /// 
  /// Retorna el idioma correspondiente al código proporcionado,
  /// o null si no se encuentra.
  static Language? findLanguageByCode(String code) {
    try {
      return allSupportedLanguages.firstWhere(
        (language) => language.code.toLowerCase() == code.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Encuentra un idioma por su nombre
  /// 
  /// Retorna el idioma correspondiente al nombre proporcionado,
  /// o null si no se encuentra.
  static Language? findLanguageByName(String name) {
    try {
      return allSupportedLanguages.firstWhere(
        (language) => language.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Verifica si un código de idioma está soportado
  static bool isLanguageSupported(String code) {
    return findLanguageByCode(code) != null;
  }

  /// Obtiene una lista de códigos de idioma
  static List<String> getAllLanguageCodes() {
    return allSupportedLanguages.map((lang) => lang.code).toList();
  }

  /// Obtiene una lista de nombres de idioma
  static List<String> getAllLanguageNames() {
    return allSupportedLanguages.map((lang) => lang.name).toList();
  }

  /// Obtiene la bandera emoji correspondiente a un código de idioma
  /// 
  /// Retorna un emoji de bandera representativo para el código de idioma dado.
  /// Si no encuentra una bandera específica, retorna un emoji de globo.
  static String getLanguageFlag(String languageCode) {
    switch (languageCode.toLowerCase()) {
      case 'en': return '🇺🇸';
      case 'es': return '🇪🇸';
      case 'fr': return '🇫🇷';
      case 'de': return '🇩🇪';
      case 'it': return '🇮🇹';
      case 'pt': return '🇵🇹';
      case 'ru': return '🇷🇺';
      case 'zh': return '🇨🇳';
      case 'ja': return '🇯🇵';
      case 'ko': return '🇰🇷';
      case 'nl': return '🇳🇱';
      case 'sv': return '🇸🇪';
      case 'da': return '🇩🇰';
      case 'no': return '🇳🇴';
      case 'fi': return '🇫🇮';
      case 'pl': return '🇵🇱';
      case 'cs': return '🇨🇿';
      case 'hu': return '🇭🇺';
      case 'ro': return '🇷🇴';
      case 'bg': return '🇧🇬';
      case 'hr': return '🇭🇷';
      case 'sk': return '🇸🇰';
      case 'sl': return '🇸🇮';
      case 'et': return '🇪🇪';
      case 'lv': return '🇱🇻';
      case 'lt': return '🇱🇹';
      case 'el': return '🇬🇷';
      case 'tr': return '🇹🇷';
      case 'hi': return '🇮🇳';
      case 'ar': return '🇸🇦';
      case 'th': return '🇹🇭';
      case 'vi': return '🇻🇳';
      case 'id': return '🇮🇩';
      case 'ms': return '🇲🇾';
      case 'tl': return '🇵🇭';
      case 'he': return '🇮🇱';
      case 'fa': return '🇮🇷';
      case 'ur': return '🇵🇰';
      case 'bn': return '🇧🇩';
      case 'ta': return '🇱🇰';
      case 'te': return '🇮🇳';
      case 'mr': return '🇮🇳';
      case 'gu': return '🇮🇳';
      case 'kn': return '🇮🇳';
      case 'ml': return '🇮🇳';
      case 'pa': return '🇮🇳';
      case 'pt-br': return '🇧🇷';
      case 'es-mx': return '🇲🇽';
      case 'es-ar': return '🇦🇷';
      case 'fr-ca': return '🇨🇦';
      case 'sw': return '🇹🇿';
      case 'zu': return '🇿🇦';
      case 'af': return '🇿🇦';
      case 'am': return '🇪🇹';
      case 'ig': return '🇳🇬';
      case 'yo': return '🇳🇬';
      case 'ha': return '🇳🇬';
      default: return '🌐';
    }
  }
}
