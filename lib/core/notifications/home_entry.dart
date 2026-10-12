import 'dart:developer';

import 'package:moto_passenger/core/notifications/pending_notification_router.dart';
import 'package:moto_passenger/core/notifications/session_readiness.dart';

/// Chamado quando o passageiro entra na tela inicial (spec
/// passenger-push-notifications, req 5.2, 5.3 e 5.7).
///
/// A tela inicial é o ponto comum dos dois caminhos até uma sessão pronta: a
/// abertura do app e o login depois de uma sessão expirada (que passa pela guarda
/// de termos). Aqui a sessão passa a estar pronta — toques seguintes navegam
/// direto — e o toque guardado enquanto ela não estava é aberto, uma única vez.
///
/// Nunca lança: o push não pode atrapalhar a entrada na tela inicial. Devolve
/// `true` se um toque guardado foi aberto.
bool onHomeEntered(PendingNotificationRouter Function() resolveRouter) {
  SessionReadiness.markReady();

  try {
    return resolveRouter().dispatchPending();
  } catch (e) {
    log(
      '[PUSH] Pending notification on home entry failed (${e.runtimeType}).',
      name: 'push',
      level: 900,
    );
    return false;
  }
}
