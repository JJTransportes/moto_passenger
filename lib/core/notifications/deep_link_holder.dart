import 'package:moto_passenger/core/notifications/push_notification_data.dart';

/// Armazena o toque em uma notificação até a sessão estar pronta para navegar.
///
/// Fluxo (spec passenger-push-notifications):
/// 1. O listener de clique do OneSignal recebe o toque. Com a sessão pronta
///    navega direto; senão (app abrindo, sessão expirada) chama [store].
/// 2. Ao entrar na tela inicial ou restaurar uma viagem ativa, o
///    `PendingNotificationRouter` consome e navega.
/// 3. Com a sessão expirada o toque NÃO é consumido no splash: fica guardado e
///    é aberto depois do login.
///
/// O toque vale por [maxAge]: um toque velho não navega sozinho depois.
class DeepLinkHolder {
  DeepLinkHolder._();

  /// Validade do toque guardado.
  static const Duration maxAge = Duration(minutes: 5);

  /// Relógio, substituível nos testes.
  static DateTime Function() clock = DateTime.now;

  static PushNotificationData? _pending;
  static DateTime? _storedAt;

  static void store(PushNotificationData data) {
    _pending = data;
    _storedAt = clock();
  }

  /// Devolve e descarta o toque guardado; nulo se não há ou se venceu.
  static PushNotificationData? consume() {
    final data = _freshOrNull();
    _pending = null;
    _storedAt = null;
    return data;
  }

  static bool get hasPending => _freshOrNull() != null;

  static PushNotificationData? _freshOrNull() {
    final data = _pending;
    final storedAt = _storedAt;
    if (data == null || storedAt == null) return null;
    if (clock().difference(storedAt) > maxAge) return null;
    return data;
  }
}
