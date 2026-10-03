// OneSignalPushService com um SDK falso (spec passenger-push-notifications, req 1, 2,
// 3, 5, 6 e 7): inicialização única, permissão, identificação, registro do aparelho
// best-effort, toque, primeiro plano e ausência de identificadores nos logs.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_passenger/core/notifications/deep_link_holder.dart';
import 'package:moto_passenger/core/notifications/onesignal_gateway.dart';
import 'package:moto_passenger/core/notifications/onesignal_push_service.dart';
import 'package:moto_passenger/core/notifications/push_notification_data.dart';
import 'package:moto_passenger/modules/auth/data/datasources/i_auth_datasource.dart';

class MockAuthDatasource extends Mock implements IAuthDatasource {}

class FakeGateway implements IOneSignalGateway {
  @override
  bool isSupported = true;

  @override
  String platform = 'android';

  @override
  String? pushSubscriptionId = 'sub-secret-123';

  int initializeCalls = 0;
  final initializedWith = <String>[];
  final logins = <String>[];
  int logoutCalls = 0;
  int permissionCalls = 0;
  bool permissionResult = true;

  bool throwOnInitialize = false;
  bool throwOnLogin = false;
  bool throwOnLogout = false;
  bool throwOnPermission = false;
  Completer<void>? initializeGate;

  void Function(String?)? subscriptionListener;
  void Function(PushNotificationContent)? clickListener;
  bool Function(PushNotificationContent)? displayListener;
  int subscriptionListenerRegistrations = 0;
  int clickListenerRegistrations = 0;
  int displayListenerRegistrations = 0;

  @override
  Future<void> initialize(String appId) async {
    initializeCalls++;
    initializedWith.add(appId);
    if (throwOnInitialize) throw StateError('sdk indisponível');
    await initializeGate?.future;
  }

  @override
  Future<bool> requestPermission() async {
    permissionCalls++;
    if (throwOnPermission) throw StateError('permissão falhou');
    return permissionResult;
  }

  @override
  Future<void> login(String externalId) async {
    if (throwOnLogin) throw StateError('login falhou');
    logins.add(externalId);
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
    if (throwOnLogout) throw StateError('logout falhou');
  }

  @override
  void onSubscriptionChanged(void Function(String? id) listener) {
    subscriptionListenerRegistrations++;
    subscriptionListener = listener;
  }

  @override
  void onNotificationClicked(void Function(PushNotificationContent content) listener) {
    clickListenerRegistrations++;
    clickListener = listener;
  }

  @override
  void onNotificationWillDisplay(bool Function(PushNotificationContent content) shouldSuppress) {
    displayListenerRegistrations++;
    displayListener = shouldSuppress;
  }

  void emitSubscription(String? id) {
    pushSubscriptionId = id;
    subscriptionListener?.call(id);
  }
}

PushNotificationContent _content(String type, {String? travelId = 'travel-1'}) => PushNotificationContent(
      additionalData: {'type': type, if (travelId != null) 'travelId': travelId},
      title: 'Título',
      body: 'Corpo',
    );

void main() {
  late FakeGateway gateway;
  late MockAuthDatasource auth;
  late List<String> logs;
  late List<PushNotificationData> navigated;
  late bool sessionReady;
  late String? travelOnScreen;

  OneSignalPushService build({Duration initTimeout = const Duration(seconds: 5)}) => OneSignalPushService(
        gateway,
        auth,
        initTimeout: initTimeout,
        isSessionReady: () => sessionReady,
        navigate: navigated.add,
        travelOnScreen: () => travelOnScreen,
        log: logs.add,
      );

  setUp(() {
    gateway = FakeGateway();
    auth = MockAuthDatasource();
    logs = [];
    navigated = [];
    sessionReady = false;
    travelOnScreen = null;
    DeepLinkHolder.clock = DateTime.now;
    DeepLinkHolder.consume();
    when(() => auth.registerDeviceToken(any(), any())).thenAnswer((_) async {});
  });

  tearDown(DeepLinkHolder.consume);

  // ─── Inicialização (1.1, 1.4, 1.5, 1.6, 1.7) ───────────────────────────

  group('initialize', () {
    test('inicializa o SDK com o identificador e registra os listeners', () async {
      final service = build();

      await service.initialize('app-123');

      expect(gateway.initializedWith, ['app-123']);
      expect(gateway.subscriptionListenerRegistrations, 1);
      expect(gateway.clickListenerRegistrations, 1);
      expect(gateway.displayListenerRegistrations, 1);
    });

    test('inicializa uma única vez, mesmo chamado várias vezes', () async {
      final service = build();

      await service.initialize('app-123');
      await service.initialize('app-123');
      await Future.wait([service.initialize('app-123'), service.initialize('app-123')]);

      expect(gateway.initializeCalls, 1);
      expect(gateway.clickListenerRegistrations, 1);
    });

    test('chamadas simultâneas durante a inicialização também resultam em uma só', () async {
      gateway.initializeGate = Completer<void>();
      final service = build();

      final first = service.initialize('app-123');
      final second = service.initialize('app-123');
      gateway.initializeGate!.complete();
      await Future.wait([first, second]);

      expect(gateway.initializeCalls, 1);
    });

    test('identificador vazio não inicializa e não lança', () async {
      final service = build();

      await expectLater(service.initialize(''), completes);
      await service.initialize('   ');

      expect(gateway.initializeCalls, 0);
      expect(logs, isNotEmpty); // registra que ficou sem push
    });

    test('plataforma sem suporte retorna sem erro e sem inicializar', () async {
      gateway.isSupported = false;
      final service = build();

      await expectLater(service.initialize('app-123'), completes);

      expect(gateway.initializeCalls, 0);
    });

    test('falha do SDK na inicialização não lança', () async {
      gateway.throwOnInitialize = true;
      final service = build();

      await expectLater(service.initialize('app-123'), completes);

      expect(gateway.clickListenerRegistrations, 0);
      expect(logs.any((l) => l.contains('[PUSH]')), isTrue);
    });

    test('inicialização que demora além do limite não bloqueia o app', () async {
      gateway.initializeGate = Completer<void>(); // nunca completa
      final service = build(initTimeout: const Duration(milliseconds: 30));

      await expectLater(service.initialize('app-123'), completes);
    });
  });

  // ─── Permissão (1.2, 1.3) ──────────────────────────────────────────────

  group('requestPermission', () {
    test('devolve o que o usuário decidiu', () async {
      final service = build();
      await service.initialize('app-123');

      gateway.permissionResult = true;
      expect(await service.requestPermission(), isTrue);

      gateway.permissionResult = false;
      expect(await service.requestPermission(), isFalse);
    });

    test('negar a permissão não lança nem impede a identificação', () async {
      gateway.permissionResult = false;
      final service = build();
      await service.initialize('app-123');

      expect(await service.requestPermission(), isFalse);
      await service.identify('user-1');

      expect(gateway.logins, ['user-1']);
    });

    test('antes de inicializar não chama o SDK e devolve falso', () async {
      final service = build();

      expect(await service.requestPermission(), isFalse);
      expect(gateway.permissionCalls, 0);
    });

    test('falha do SDK devolve falso sem lançar', () async {
      gateway.throwOnPermission = true;
      final service = build();
      await service.initialize('app-123');

      expect(await service.requestPermission(), isFalse);
    });
  });

  // ─── Identificação e registro (2.1, 2.5, 2.6, 3.1, 3.2) ────────────────

  group('identify', () {
    test('identifica pelo userId e registra o aparelho com a plataforma', () async {
      final service = build();
      await service.initialize('app-123');

      await service.identify('user-1');

      expect(gateway.logins, ['user-1']);
      verify(() => auth.registerDeviceToken('sub-secret-123', 'android')).called(1);
    });

    test('usa a plataforma do aparelho (ios)', () async {
      gateway.platform = 'ios';
      final service = build();
      await service.initialize('app-123');

      await service.identify('user-1');

      verify(() => auth.registerDeviceToken('sub-secret-123', 'ios')).called(1);
    });

    test('identificação pedida antes do fim da inicialização é aplicada depois', () async {
      gateway.initializeGate = Completer<void>();
      final service = build();

      final init = service.initialize('app-123');
      await service.identify('user-1');
      expect(gateway.logins, isEmpty);

      gateway.initializeGate!.complete();
      await init;

      expect(gateway.logins, ['user-1']);
      verify(() => auth.registerDeviceToken(any(), any())).called(1);
    });

    test('identificação pedida antes de inicializar é aplicada quando inicializar', () async {
      final service = build();

      await service.identify('user-1');
      expect(gateway.logins, isEmpty);

      await service.initialize('app-123');

      expect(gateway.logins, ['user-1']);
    });

    test('userId vazio é ignorado', () async {
      final service = build();
      await service.initialize('app-123');

      await service.identify('');
      await service.identify('   ');

      expect(gateway.logins, isEmpty);
      verifyNever(() => auth.registerDeviceToken(any(), any()));
    });

    test('sem identificador do aparelho ainda, identifica e espera a assinatura para registrar', () async {
      gateway.pushSubscriptionId = null;
      final service = build();
      await service.initialize('app-123');

      await service.identify('user-1');

      expect(gateway.logins, ['user-1']);
      verifyNever(() => auth.registerDeviceToken(any(), any()));

      gateway.emitSubscription('sub-late-1');
      await Future<void>.delayed(Duration.zero);

      verify(() => auth.registerDeviceToken('sub-late-1', 'android')).called(1);
    });

    test('assinatura que muda sem usuário identificado não registra nada', () async {
      final service = build();
      await service.initialize('app-123');

      gateway.emitSubscription('sub-x');
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => auth.registerDeviceToken(any(), any()));
    });

    test('a mesma assinatura notificada de novo não registra duas vezes', () async {
      final service = build();
      await service.initialize('app-123');
      await service.identify('user-1');

      gateway.emitSubscription('sub-secret-123');
      gateway.emitSubscription('sub-secret-123');
      await Future<void>.delayed(Duration.zero);

      verify(() => auth.registerDeviceToken('sub-secret-123', 'android')).called(1);
    });

    test('uma assinatura nova do mesmo usuário é registrada', () async {
      final service = build();
      await service.initialize('app-123');
      await service.identify('user-1');

      gateway.emitSubscription('sub-novo');
      await Future<void>.delayed(Duration.zero);

      verify(() => auth.registerDeviceToken('sub-secret-123', 'android')).called(1);
      verify(() => auth.registerDeviceToken('sub-novo', 'android')).called(1);
    });

    test('trocar de usuário identifica o novo e registra de novo para ele', () async {
      final service = build();
      await service.initialize('app-123');

      await service.identify('user-1');
      await service.clear();
      await service.identify('user-2');

      expect(gateway.logins, ['user-1', 'user-2']);
      verify(() => auth.registerDeviceToken('sub-secret-123', 'android')).called(2);
    });

    test('falha no registro no backend não lança e é registrada em log', () async {
      when(() => auth.registerDeviceToken(any(), any())).thenThrow(StateError('backend fora'));
      final service = build();
      await service.initialize('app-123');

      await expectLater(service.identify('user-1'), completes);

      expect(gateway.logins, ['user-1']);
      expect(logs.any((l) => l.contains('[PUSH]')), isTrue);
    });

    test('falha do SDK no login não lança', () async {
      gateway.throwOnLogin = true;
      final service = build();
      await service.initialize('app-123');

      await expectLater(service.identify('user-1'), completes);

      verifyNever(() => auth.registerDeviceToken(any(), any()));
    });
  });

  // ─── Logout (2.3, 2.4, 2.5, 4.6) ───────────────────────────────────────

  group('clear', () {
    test('remove a identificação no SDK', () async {
      final service = build();
      await service.initialize('app-123');
      await service.identify('user-1');

      await service.clear();

      expect(gateway.logoutCalls, 1);
    });

    test('falha do SDK no logout não lança', () async {
      gateway.throwOnLogout = true;
      final service = build();
      await service.initialize('app-123');
      await service.identify('user-1');

      await expectLater(service.clear(), completes);
    });

    test('limpar antes de inicializar cancela a identificação pendente', () async {
      final service = build();
      await service.identify('user-1');

      await service.clear();
      await service.initialize('app-123');

      expect(gateway.logins, isEmpty);
    });

    test('limpar durante a inicialização cancela a identificação pedida antes', () async {
      gateway.initializeGate = Completer<void>();
      final service = build();
      final init = service.initialize('app-123');
      await service.identify('user-1');

      await service.clear();
      gateway.initializeGate!.complete();
      await init;

      expect(gateway.logins, isEmpty);
    });

    test('depois de limpar, uma assinatura nova não registra aparelho para o usuário anterior', () async {
      final service = build();
      await service.initialize('app-123');
      await service.identify('user-1');
      await service.clear();

      gateway.emitSubscription('sub-depois');
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => auth.registerDeviceToken('sub-depois', any()));
    });

    test('sem SDK inicializado não chama o logout', () async {
      final service = build();

      await service.clear();

      expect(gateway.logoutCalls, 0);
    });
  });

  // ─── Toque (5.1, 5.2, 5.3) ─────────────────────────────────────────────

  group('toque na notificação', () {
    test('com a sessão pronta navega direto para a viagem', () async {
      sessionReady = true;
      final service = build();
      await service.initialize('app-123');

      gateway.clickListener!(_content('DriverArrived'));

      expect(navigated.single.type, 'DriverArrived');
      expect(navigated.single.travelId, 'travel-1');
      expect(DeepLinkHolder.hasPending, isFalse);
    });

    test('com a sessão não pronta guarda o toque e não navega', () async {
      sessionReady = false;
      final service = build();
      await service.initialize('app-123');

      gateway.clickListener!(_content('OrderAccepted'));

      expect(navigated, isEmpty);
      expect(DeepLinkHolder.hasPending, isTrue);
      expect(DeepLinkHolder.consume()!.travelId, 'travel-1');
    });

    test('falha na navegação não propaga', () async {
      sessionReady = true;
      final service = OneSignalPushService(
        gateway,
        auth,
        isSessionReady: () => true,
        navigate: (_) => throw StateError('navegação falhou'),
        travelOnScreen: () => null,
        log: logs.add,
      );
      await service.initialize('app-123');

      expect(() => gateway.clickListener!(_content('DriverArrived')), returnsNormally);
    });

    test('conteúdo sem dados vira tipo vazio (a navegação cai na tela inicial)', () async {
      sessionReady = true;
      final service = build();
      await service.initialize('app-123');

      gateway.clickListener!(const PushNotificationContent(additionalData: null, title: null, body: null));

      expect(navigated.single.type, isEmpty);
      expect(navigated.single.travelId, isNull);
    });
  });

  // ─── Primeiro plano (6.1 a 6.4) ────────────────────────────────────────

  group('primeiro plano', () {
    test('suprime o aviso da mesma viagem que está na tela', () async {
      travelOnScreen = 'travel-1';
      final service = build();
      await service.initialize('app-123');

      expect(gateway.displayListener!(_content('DriverArrived')), isTrue);
    });

    test('não suprime em outra tela', () async {
      travelOnScreen = null;
      final service = build();
      await service.initialize('app-123');

      expect(gateway.displayListener!(_content('DriverArrived')), isFalse);
    });

    test('não suprime o aviso de outra viagem', () async {
      travelOnScreen = 'travel-2';
      final service = build();
      await service.initialize('app-123');

      expect(gateway.displayListener!(_content('OrderAccepted')), isFalse);
    });

    test('não suprime tipo desconhecido', () async {
      travelOnScreen = 'travel-1';
      final service = build();
      await service.initialize('app-123');

      expect(gateway.displayListener!(_content('AlgoNovo')), isFalse);
    });

    test('falha ao descobrir a tela atual não suprime (o aviso aparece)', () async {
      final service = OneSignalPushService(
        gateway,
        auth,
        isSessionReady: () => true,
        navigate: navigated.add,
        travelOnScreen: () => throw StateError('rota indisponível'),
        log: logs.add,
      );
      await service.initialize('app-123');

      expect(gateway.displayListener!(_content('DriverArrived')), isFalse);
    });
  });

  // ─── Privacidade (3.5) ─────────────────────────────────────────────────

  // O backend serializa o `data` do push em snake_case: o travelId chega como `travel_id`.
  group('payload com travel_id (como o backend envia)', () {
    PushNotificationContent snake(String type) => PushNotificationContent(
          additionalData: {'type': type, 'travel_id': 'travel-1'},
          title: 't',
          body: 'b',
        );

    test('o toque abre a viagem certa', () async {
      sessionReady = true;
      final service = build();
      await service.initialize('app-123');

      gateway.clickListener!(snake('DriverArrived'));

      expect(navigated.single.travelId, 'travel-1');
    });

    test('o toque com a sessão não pronta guarda o travelId', () async {
      sessionReady = false;
      final service = build();
      await service.initialize('app-123');

      gateway.clickListener!(snake('OrderAccepted'));

      expect(DeepLinkHolder.consume()!.travelId, 'travel-1');
    });

    test('a supressão em primeiro plano casa a viagem da tela', () async {
      travelOnScreen = 'travel-1';
      final service = build();
      await service.initialize('app-123');

      expect(gateway.displayListener!(snake('DriverNearby')), isTrue);
    });
  });

  group('privacidade', () {
    test('nenhum log contém o identificador do aparelho', () async {
      final service = build();
      await service.initialize('app-123');
      await service.identify('user-1');
      gateway.emitSubscription('sub-novo-456');
      await Future<void>.delayed(Duration.zero);

      expect(logs, isNotEmpty);
      expect(logs.any((l) => l.contains('sub-secret-123')), isFalse);
      expect(logs.any((l) => l.contains('sub-novo-456')), isFalse);
    });

    test('nenhum log contém o identificador do aparelho nos caminhos de falha', () async {
      when(() => auth.registerDeviceToken(any(), any())).thenThrow(StateError('falhou com sub-secret-123'));
      gateway.throwOnLogout = true;
      final service = build();
      await service.initialize('app-123');
      await service.identify('user-1');
      await service.clear();

      expect(logs, isNotEmpty);
      expect(logs.any((l) => l.contains('sub-secret-123')), isFalse);
    });
  });
}
