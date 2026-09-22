import 'package:flutter_test/flutter_test.dart';
import 'package:moto_passenger/core/notifications/deep_link_holder.dart';
import 'package:moto_passenger/core/notifications/push_notification_data.dart';

void main() {
  group('DeepLinkHolder', () {
    final testData = PushNotificationData(
      type: 'OrderAccepted',
      travelId: 'travel-123',
      title: 'Test',
      body: 'Test body',
      rawPayload: {'type': 'OrderAccepted', 'travelId': 'travel-123'},
    );

    setUp(() {
      // Garantir estado limpo antes de cada teste
      DeepLinkHolder.consume();
    });

    test('store and consume returns stored data', () {
      DeepLinkHolder.store(testData);
      final consumed = DeepLinkHolder.consume();
      expect(consumed, isNotNull);
      expect(consumed!.travelId, 'travel-123');
    });

    test('consume clears holder after consumption', () {
      DeepLinkHolder.store(testData);
      DeepLinkHolder.consume();
      final second = DeepLinkHolder.consume();
      expect(second, isNull);
    });

    test('hasPending returns true when data stored', () {
      DeepLinkHolder.store(testData);
      expect(DeepLinkHolder.hasPending, isTrue);
    });

    test('hasPending returns false after consume', () {
      DeepLinkHolder.store(testData);
      DeepLinkHolder.consume();
      expect(DeepLinkHolder.hasPending, isFalse);
    });

    test('hasPending returns false when empty', () {
      expect(DeepLinkHolder.hasPending, isFalse);
    });

    test('multiple stores overwrite previous', () {
      DeepLinkHolder.store(testData);
      final newData = PushNotificationData(
        type: 'TravelStarted',
        travelId: 'travel-456',
        title: 'Test 2',
        body: 'Test body 2',
        rawPayload: {'type': 'TravelStarted'},
      );
      DeepLinkHolder.store(newData);
      final consumed = DeepLinkHolder.consume();
      expect(consumed!.travelId, 'travel-456');
    });
  });
}
