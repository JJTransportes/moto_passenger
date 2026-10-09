// Spec passenger-push-notifications (req 5.2, 5.3, 5.7): despacha o toque guardado
// quando a sessão está pronta — ao entrar na tela inicial ou restaurar uma viagem.
import 'package:flutter_test/flutter_test.dart';
import 'package:moto_passenger/core/notifications/deep_link_holder.dart';
import 'package:moto_passenger/core/notifications/pending_notification_router.dart';
import 'package:moto_passenger/core/notifications/push_notification_data.dart';

void main() {
  const data = PushNotificationData(
    type: 'OrderAccepted',
    travelId: 'travel-1',
    title: 't',
    body: 'b',
    rawPayload: {},
  );

  late List<PushNotificationData> handled;
  late PendingNotificationRouter router;

  setUp(() {
    DeepLinkHolder.clock = DateTime.now;
    DeepLinkHolder.consume();
    handled = [];
    router = PendingNotificationRouter(handled.add);
  });

  tearDown(DeepLinkHolder.consume);

  test('sem toque guardado não faz nada e devolve falso', () {
    expect(router.dispatchPending(), isFalse);
    expect(handled, isEmpty);
  });

  test('despacha o toque guardado para a navegação e devolve verdadeiro', () {
    DeepLinkHolder.store(data);

    expect(router.dispatchPending(), isTrue);

    expect(handled, hasLength(1));
    expect(handled.single.travelId, 'travel-1');
  });

  test('descarta o toque depois de despachar (não abre uma segunda vez)', () {
    DeepLinkHolder.store(data);

    router.dispatchPending();

    expect(DeepLinkHolder.hasPending, isFalse);
    expect(router.dispatchPending(), isFalse);
    expect(handled, hasLength(1));
  });

  test('um toque vencido não é despachado', () {
    var now = DateTime.utc(2026, 10, 2, 15);
    DeepLinkHolder.clock = () => now;
    DeepLinkHolder.store(data);
    now = now.add(const Duration(minutes: 10));

    expect(router.dispatchPending(), isFalse);
    expect(handled, isEmpty);
  });

  test('uma falha na navegação não propaga e o toque já foi descartado', () {
    DeepLinkHolder.store(data);
    final failing = PendingNotificationRouter((_) => throw StateError('navegação falhou'));

    expect(() => failing.dispatchPending(), returnsNormally);
    expect(DeepLinkHolder.hasPending, isFalse);
  });
}
