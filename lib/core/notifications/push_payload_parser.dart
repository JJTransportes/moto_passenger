import 'package:moto_passenger/core/notifications/push_notification_data.dart';

/// Converte o conteúdo da notificação do SDK em [PushNotificationData] (spec
/// passenger-push-notifications, req 4.7, 5.5, 5.6, 7.3).
///
/// Tolerante: campos ausentes ou de tipo inesperado viram vazio/nulo, nunca
/// lançam. Só tipo e identificadores são lidos e repassados — nenhum dado
/// pessoal entra no payload bruto guardado.
class PushPayloadParser {
  PushPayloadParser._();

  static PushNotificationData parse({
    required Map<String, dynamic>? additionalData,
    String? title,
    String? body,
  }) {
    final data = additionalData ?? const <String, dynamic>{};

    final type = _text(data['type']);
    // O backend serializa o `data` em snake_case (`travel_id`); camelCase continua aceito.
    final travelId = _text(data['travelId']) ?? _text(data['travel_id']);
    final orderId = _text(data['orderId']) ?? _text(data['order_id']);

    return PushNotificationData(
      type: type ?? '',
      travelId: travelId,
      orderId: orderId,
      title: title ?? '',
      body: body ?? '',
      rawPayload: {
        if (type != null) 'type': type,
        if (travelId != null) 'travelId': travelId,
        if (orderId != null) 'orderId': orderId,
      },
    );
  }

  /// Texto aparado, ou nulo se não for uma string não vazia.
  static String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
