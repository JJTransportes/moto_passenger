import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String _baseUrl = '';
  static String _oneSignalAppId = '';

  static String getBaseUrl() => _baseUrl;

  /// Identificador do app no OneSignal. Vazio significa "sem push": o app
  /// inicia normalmente, apenas sem notificações (spec passenger-push-notifications).
  static String getOneSignalAppId() => _oneSignalAppId;

  static Future<void> loadEnv() async {
    _baseUrl = dotenv.get('API_BASE_URL');
    // Leitura tolerante: `dotenv.get` lançaria se a variável faltasse e o app
    // não abriria. Sem o identificador, só não há push.
    _oneSignalAppId = (dotenv.maybeGet('ONE_SIGNAL_ID') ?? '').trim();
  }
}
