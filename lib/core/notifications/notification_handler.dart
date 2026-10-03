import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_passenger/core/notifications/push_notification_data.dart';

/// Rota atual e seus argumentos, lidos pelo [NotificationHandler].
class RouteSnapshot {
  final String path;
  final Map<String, dynamic>? args;

  const RouteSnapshot(this.path, this.args);
}

class NotificationHandler {
  static const String _trackingPath = '/new-travel/tracking';

  /// Leitor da rota atual. Padrão: o Modular; substituível nos testes.
  static RouteSnapshot Function() routeReader = modularRouteReader;

  static RouteSnapshot modularRouteReader() {
    String path = '';
    try {
      path = Modular.to.path;
    } catch (_) {}

    Map<String, dynamic>? args;
    try {
      final data = Modular.args.data;
      if (data is Map) {
        args = Map<String, dynamic>.from(data);
      }
    } catch (_) {}

    return RouteSnapshot(path, args);
  }

  /// Processa o toque em uma notificação push.
  /// Navega para a tela apropriada baseada no [data.type].
  static void handleNotificationTap(PushNotificationData data) {
    // Evitar dupla navegação para tracking com mesmo travelId
    if (_isTrackingType(data.type) && isViewingTravel(data.travelId)) {
      return; // já está na tela correta com o mesmo travelId
    }

    switch (data.type) {
      case 'OrderAccepted':
      case 'TravelStarted':
      case 'DriverNearby':
      case 'DriverArrived':
        if (data.travelId != null) {
          Modular.to.navigate(_trackingPath,
              arguments: {'travelId': data.travelId});
        } else {
          Modular.to.navigate('/home');
        }
      case 'TravelCompleted':
      case 'TravelCancelled':
        Modular.to.navigate('/home');
      default:
        Modular.to.navigate('/home');
    }
  }

  /// Se o acompanhamento da viagem [travelId] é a tela atual.
  static bool isViewingTravel(String? travelId) {
    if (travelId == null || travelId.isEmpty) return false;
    return travelOnScreen() == travelId;
  }

  /// A viagem mostrada no acompanhamento agora, ou nulo se a tela atual é outra.
  static String? travelOnScreen() {
    final route = routeReader();
    if (route.path != _trackingPath) return null;
    final id = route.args?['travelId'];
    return id is String && id.isNotEmpty ? id : null;
  }

  /// Pushes que levam à tela de acompanhamento da viagem.
  static bool _isTrackingType(String type) =>
      type == 'OrderAccepted' ||
      type == 'TravelStarted' ||
      type == 'DriverNearby' ||
      type == 'DriverArrived';
}
