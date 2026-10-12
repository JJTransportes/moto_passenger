/// Notificações push do passageiro (spec passenger-push-notifications).
///
/// Nenhum método lança: push é um complemento, e uma falha dele nunca pode
/// impedir o login, a navegação nem o acompanhamento da corrida.
abstract class IPushNotificationService {
  /// Inicializa o SDK uma única vez. Retorna cedo sem identificador, em
  /// plataforma sem suporte, em falha ou depois de um tempo limite.
  Future<void> initialize(String appId);

  /// Pede a permissão de notificações. `false` se negada ou indisponível.
  Future<bool> requestPermission();

  /// Identifica o aparelho com o [userId] e registra o aparelho no backend.
  /// Pode ser chamado antes de [initialize] terminar: a identificação fica
  /// pendente e é aplicada em seguida.
  Future<void> identify(String userId);

  /// Remove a identificação (logout, exclusão de conta, sessão expirada), para o
  /// aparelho deixar de receber os avisos da conta.
  Future<void> clear();
}
