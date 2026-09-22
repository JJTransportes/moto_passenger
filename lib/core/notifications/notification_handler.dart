import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_passenger/core/notifications/push_notification_data.dart';

class NotificationHandler {
  /// Processa o toque em uma notificação push (warm start).
  /// Navega para a tela apropriada baseada no [data.type].
  static void handleNotificationTap(PushNotificationData data) {
    final currentPath = Modular.to.path;

    // Evitar dupla navegação para tracking com mesmo travelId
    if (data.type == 'OrderAccepted' || data.type == 'TravelStarted') {
      final currentArgs = _currentRouteArgs();
      final currentTravelId = currentArgs?['travelId'];

      if (currentPath == '/new-travel/tracking' &&
          currentTravelId == data.travelId) {
        return; // já está na tela correta com o mesmo travelId
      }
    }

    switch (data.type) {
      case 'OrderAccepted':
      case 'TravelStarted':
        if (data.travelId != null) {
          Modular.to.navigate('/new-travel/tracking',
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

  static Map<String, dynamic>? _currentRouteArgs() {
    try {
      final args = Modular.args.data;
      if (args is Map) {
        return Map<String, dynamic>.from(args);
      }
    } catch (_) {}
    return null;
  }
}
