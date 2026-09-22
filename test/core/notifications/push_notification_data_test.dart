import 'package:flutter_test/flutter_test.dart';
import 'package:moto_passenger/core/notifications/push_notification_data.dart';

void main() {
  group('PushNotificationData', () {
    test('parses OrderAccepted payload correctly', () {
      final data = PushNotificationData(
        type: 'OrderAccepted',
        travelId: 'travel-123',
        title: 'Motorista encontrado!',
        body: 'Seu motorista aceitou a viagem.',
        rawPayload: {'type': 'OrderAccepted', 'travelId': 'travel-123'},
      );

      expect(data.type, 'OrderAccepted');
      expect(data.travelId, 'travel-123');
      expect(data.orderId, isNull);
      expect(data.title, 'Motorista encontrado!');
    });

    test('handles empty type gracefully', () {
      final data = PushNotificationData(
        type: '',
        title: '',
        body: '',
        rawPayload: {},
      );

      expect(data.type, isEmpty);
      expect(data.travelId, isNull);
      expect(data.orderId, isNull);
    });

    test('handles unknown payload fields gracefully', () {
      final data = PushNotificationData(
        type: 'UnknownEvent',
        travelId: null,
        orderId: null,
        title: 'Unknown',
        body: 'Unknown',
        rawPayload: {'type': 'UnknownEvent', 'extra': 'data'},
      );

      expect(data.type, 'UnknownEvent');
      expect(data.rawPayload['extra'], 'data');
    });

    test('rawPayload preserves all additional data', () {
      final payload = {
        'type': 'OrderAccepted',
        'travelId': 'travel-123',
        'customField': 'customValue',
      };
      final data = PushNotificationData(
        type: 'OrderAccepted',
        travelId: 'travel-123',
        title: 'Test',
        body: 'Test',
        rawPayload: payload,
      );

      expect(data.rawPayload['customField'], 'customValue');
    });
  });
}
