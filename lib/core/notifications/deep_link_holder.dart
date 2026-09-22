import 'package:moto_passenger/core/notifications/push_notification_data.dart';

/// Armazena notificação de cold start para processamento após autenticação.
///
/// Fluxo:
/// 1. main() captura getInitialNotification() → store()
/// 2. SplashScreen._checkAuth():
///    - Autenticado → consume() → processa
///    - JWT expirado → NÃO consome → preserva para pós-login
/// 3. Fluxo pós-login (T5) → consume() → processa
class DeepLinkHolder {
  static PushNotificationData? _pending;

  static void store(PushNotificationData data) => _pending = data;

  static PushNotificationData? consume() {
    final data = _pending;
    _pending = null;
    return data;
  }

  static bool get hasPending => _pending != null;
}
