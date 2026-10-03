/// Indica se a sessão do passageiro está pronta para navegar por um toque em
/// notificação (spec passenger-push-notifications, req 5.2 e 5.3).
///
/// Fica pronta quando o app entra na tela inicial ou restaura uma viagem ativa, e
/// deixa de estar pronta na saída de sessão. Enquanto não estiver, um toque é
/// guardado no `DeepLinkHolder` em vez de navegar.
class SessionReadiness {
  SessionReadiness._();

  static bool _ready = false;

  static bool get isReady => _ready;

  static void markReady() => _ready = true;

  static void reset() => _ready = false;
}
