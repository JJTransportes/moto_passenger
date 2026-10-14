// Entrada na tela inicial (spec passenger-push-notifications, req 5.2, 5.3, 5.7 e 7.1):
// a sessão passa a estar pronta e o toque guardado é aberto uma única vez — inclusive
// depois de um login por sessão expirada.
import 'package:flutter_test/flutter_test.dart';
import 'package:moto_passenger/core/notifications/deep_link_holder.dart';
import 'package:moto_passenger/core/notifications/home_entry.dart';
import 'package:moto_passenger/core/notifications/pending_notification_router.dart';
import 'package:moto_passenger/core/notifications/push_notification_data.dart';
import 'package:moto_passenger/core/notifications/session_readiness.dart';

void main() {
  const tap = PushNotificationData(
    type: 'DriverArrived',
    travelId: 'travel-1',
    title: 't',
    body: 'b',
    rawPayload: {},
  );

  late List<PushNotificationData> opened;
  late PendingNotificationRouter router;

  setUp(() {
    DeepLinkHolder.clock = DateTime.now;
    DeepLinkHolder.consume();
    SessionReadiness.reset();
    opened = [];
    router = PendingNotificationRouter(opened.add);
  });

  tearDown(() {
    DeepLinkHolder.consume();
    SessionReadiness.reset();
  });

  test('entrar na tela inicial marca a sessão como pronta', () {
    onHomeEntered(() => router);

    expect(SessionReadiness.isReady, isTrue);
  });

  test('abre o toque guardado ao entrar na tela inicial e devolve verdadeiro', () {
    DeepLinkHolder.store(tap);

    final dispatched = onHomeEntered(() => router);

    expect(dispatched, isTrue);
    expect(opened.single.travelId, 'travel-1');
  });

  test('sem toque guardado não abre nada e devolve falso', () {
    final dispatched = onHomeEntered(() => router);

    expect(dispatched, isFalse);
    expect(opened, isEmpty);
  });

  test('abre uma única vez, mesmo entrando na tela inicial várias vezes', () {
    DeepLinkHolder.store(tap);

    onHomeEntered(() => router);
    onHomeEntered(() => router);
    onHomeEntered(() => router);

    expect(opened, hasLength(1));
  });

  test('toque guardado durante a sessão expirada abre depois do login (ao entrar na tela inicial)', () {
    // 1. sessão não pronta (login pendente): o toque é guardado
    expect(SessionReadiness.isReady, isFalse);
    DeepLinkHolder.store(tap);
    expect(opened, isEmpty);

    // 2. depois do login o app chega à tela inicial
    onHomeEntered(() => router);

    expect(opened.single.travelId, 'travel-1');
  });

  test('um toque vencido não abre ao entrar na tela inicial', () {
    var now = DateTime.utc(2026, 10, 2, 15);
    DeepLinkHolder.clock = () => now;
    DeepLinkHolder.store(tap);
    now = now.add(const Duration(minutes: 10));

    final dispatched = onHomeEntered(() => router);

    expect(dispatched, isFalse);
    expect(opened, isEmpty);
  });

  test('a sessão fica pronta mesmo que o roteador não possa ser resolvido', () {
    final dispatched = onHomeEntered(() => throw StateError('sem módulo'));

    expect(dispatched, isFalse);
    expect(SessionReadiness.isReady, isTrue);
  });

  test('falha ao abrir o toque não propaga', () {
    DeepLinkHolder.store(tap);
    final failing = PendingNotificationRouter((_) => throw StateError('navegação falhou'));

    expect(() => onHomeEntered(() => failing), returnsNormally);
  });
}
