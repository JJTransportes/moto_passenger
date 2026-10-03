import 'dart:developer';

import 'package:moto_passenger/core/notifications/deep_link_holder.dart';
import 'package:moto_passenger/core/notifications/push_notification_data.dart';

/// Despacha o toque guardado no [DeepLinkHolder] quando a sessão está pronta
/// (spec passenger-push-notifications, req 5.2, 5.3, 5.7).
///
/// É chamado ao entrar na tela inicial (abertura do app ou login depois de uma
/// sessão expirada) e ao restaurar uma viagem ativa. O toque é descartado ao ser
/// consumido, então nunca abre duas vezes.
class PendingNotificationRouter {
  final void Function(PushNotificationData data) _navigate;

  PendingNotificationRouter(this._navigate);

  /// Devolve `true` se havia um toque válido e ele foi despachado.
  bool dispatchPending() {
    final pending = DeepLinkHolder.consume();
    if (pending == null) return false;

    try {
      _navigate(pending);
    } catch (e) {
      // Já foi descartado; falha de navegação não pode derrubar a abertura do app.
      log('[PUSH] Failed to open pending notification: $e', name: 'push', level: 900);
    }
    return true;
  }
}
