// Spec passenger-push-notifications (req 5.2, 5.3, 5.7): o toque guardado vale por
// pouco tempo — um toque velho não pode navegar sozinho depois.
import 'package:flutter_test/flutter_test.dart';
import 'package:moto_passenger/core/notifications/deep_link_holder.dart';
import 'package:moto_passenger/core/notifications/push_notification_data.dart';

void main() {
  const data = PushNotificationData(
    type: 'DriverArrived',
    travelId: 'travel-1',
    title: 't',
    body: 'b',
    rawPayload: {'type': 'DriverArrived', 'travelId': 'travel-1'},
  );

  late DateTime now;

  setUp(() {
    now = DateTime.utc(2026, 10, 2, 15);
    DeepLinkHolder.clock = () => now;
    DeepLinkHolder.consume();
  });

  tearDown(() {
    DeepLinkHolder.clock = DateTime.now;
    DeepLinkHolder.consume();
  });

  test('a validade padrão é de 5 minutos', () {
    expect(DeepLinkHolder.maxAge, const Duration(minutes: 5));
  });

  test('um toque recente é consumido', () {
    DeepLinkHolder.store(data);
    now = now.add(const Duration(minutes: 4, seconds: 59));

    expect(DeepLinkHolder.hasPending, isTrue);
    expect(DeepLinkHolder.consume()?.travelId, 'travel-1');
  });

  test('um toque com mais de 5 minutos é descartado', () {
    DeepLinkHolder.store(data);
    now = now.add(const Duration(minutes: 5, seconds: 1));

    expect(DeepLinkHolder.consume(), isNull);
  });

  test('hasPending é falso para um toque vencido', () {
    DeepLinkHolder.store(data);
    now = now.add(const Duration(minutes: 6));

    expect(DeepLinkHolder.hasPending, isFalse);
  });

  test('um toque vencido é descartado e não volta', () {
    DeepLinkHolder.store(data);
    now = now.add(const Duration(minutes: 6));
    DeepLinkHolder.consume();

    now = now.subtract(const Duration(minutes: 6)); // relógio "volta"
    expect(DeepLinkHolder.consume(), isNull);
  });

  test('guardar de novo renova o horário', () {
    DeepLinkHolder.store(data);
    now = now.add(const Duration(minutes: 4));
    DeepLinkHolder.store(data);
    now = now.add(const Duration(minutes: 4));

    expect(DeepLinkHolder.consume(), isNotNull);
  });

  test('consumir descarta: a segunda leitura é nula', () {
    DeepLinkHolder.store(data);

    expect(DeepLinkHolder.consume(), isNotNull);
    expect(DeepLinkHolder.consume(), isNull);
    expect(DeepLinkHolder.hasPending, isFalse);
  });
}
