/// Decide se o banner do sistema deve ser suprimido com o app em primeiro plano
/// (spec passenger-push-notifications, req 6).
///
/// Diferente do app do motorista (que suprime sempre `NewOrder`), aqui só se
/// suprime quando o passageiro já vê, na tela, a viagem a que o aviso se refere:
/// o evento de SignalR chega ao card dessa tela e a notificação seria repetida.
/// Em qualquer outra tela o aviso do sistema aparece normalmente, porque o
/// evento em tempo real só é escutado pelo acompanhamento da viagem.
class ForegroundPushPolicy {
  ForegroundPushPolicy._();

  /// Avisos de corrida que o card da viagem já mostra por tempo real.
  static const Set<String> rideTypes = {
    'OrderAccepted',
    'DriverNearby',
    'DriverArrived',
  };

  static bool shouldSuppress({
    required String type,
    required String? travelId,
    required String? travelOnScreen,
  }) {
    if (!rideTypes.contains(type)) return false;
    if (travelId == null || travelId.isEmpty) return false;
    if (travelOnScreen == null || travelOnScreen.isEmpty) return false;
    return travelId == travelOnScreen;
  }
}
