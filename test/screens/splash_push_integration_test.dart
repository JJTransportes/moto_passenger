// SplashScreen com o push (spec passenger-push-notifications, req 1.1, 1.2, 1.7, 2.2,
// 5.2, 7.1 e 7.2): inicializa e pede a permissão sem atrasar a autenticação,
// identifica a sessão restaurada e despacha o toque guardado ao restaurar a viagem.
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_passenger/core/auth/auth_storage.dart';
import 'package:moto_passenger/core/auth/sign_out_service.dart';
import 'package:moto_passenger/core/config/app_config.dart';
import 'package:moto_passenger/core/errors/exceptions.dart';
import 'package:moto_passenger/core/local_db/models/local_data_models.dart';
import 'package:moto_passenger/core/local_db/repositories/auth_local_repository.dart';
import 'package:moto_passenger/core/local_db/repositories/travel_local_repository.dart';
import 'package:moto_passenger/core/notifications/i_push_notification_service.dart';
import 'package:moto_passenger/core/notifications/notification_channel_service.dart';
import 'package:moto_passenger/core/notifications/pending_notification_router.dart';
import 'package:moto_passenger/core/notifications/session_readiness.dart';
import 'package:moto_passenger/modules/auth/data/datasources/i_auth_datasource.dart';
import 'package:moto_passenger/modules/auth/data/models/sign_in_response_model.dart';
import 'package:moto_passenger/screens/splash_screen.dart';

class MockAuthLocalRepository extends Mock implements AuthLocalRepository {}

class MockAuthDatasource extends Mock implements IAuthDatasource {}

class MockAuthStorage extends Mock implements AuthStorage {}

class MockSignOutService extends Mock implements SignOutService {}

class MockTravelLocalRepository extends Mock implements TravelLocalRepository {}

class MockDio extends Mock implements Dio {}

class MockPushNotificationService extends Mock
    implements IPushNotificationService {}

class MockPendingNotificationRouter extends Mock
    implements PendingNotificationRouter {}

class MockNotificationChannelService extends Mock
    implements INotificationChannelService {}

class MockModularNavigator extends Mock implements IModularNavigator {}

class _TestModule extends Module {
  final AuthLocalRepository authLocal;
  final IAuthDatasource datasource;
  final AuthStorage storage;
  final SignOutService signOut;
  final TravelLocalRepository travelLocal;
  final Dio dio;
  final IPushNotificationService push;
  final PendingNotificationRouter router;
  final INotificationChannelService channels;

  _TestModule({
    required this.authLocal,
    required this.datasource,
    required this.storage,
    required this.signOut,
    required this.travelLocal,
    required this.dio,
    required this.push,
    required this.router,
    required this.channels,
  });

  @override
  void binds(Injector i) {
    i.addInstance<AuthLocalRepository>(authLocal);
    i.addInstance<IAuthDatasource>(datasource);
    i.addInstance<AuthStorage>(storage);
    i.addInstance<SignOutService>(signOut);
    i.addInstance<TravelLocalRepository>(travelLocal);
    i.addInstance<Dio>(dio);
    i.addInstance<IPushNotificationService>(push);
    i.addInstance<PendingNotificationRouter>(router);
    i.addInstance<INotificationChannelService>(channels);
  }
}

void main() {
  late MockAuthLocalRepository authLocal;
  late MockAuthDatasource datasource;
  late MockAuthStorage storage;
  late MockSignOutService signOut;
  late MockTravelLocalRepository travelLocal;
  late MockDio dio;
  late MockPushNotificationService push;
  late MockPendingNotificationRouter router;
  late MockNotificationChannelService channels;
  late MockModularNavigator navigator;
  late List<String> order;

  setUp(() async {
    order = [];
    channels = MockNotificationChannelService();
    authLocal = MockAuthLocalRepository();
    datasource = MockAuthDatasource();
    storage = MockAuthStorage();
    signOut = MockSignOutService();
    travelLocal = MockTravelLocalRepository();
    dio = MockDio();
    push = MockPushNotificationService();
    router = MockPendingNotificationRouter();
    navigator = MockModularNavigator();

    dotenv.loadFromString(
      envString: 'API_BASE_URL=http://api.test\nONE_SIGNAL_ID=app-xyz',
    );
    await AppConfig.loadEnv();
    SessionReadiness.reset();

    when(
      () => channels.ensureRideAlertsChannel(),
    ).thenAnswer((_) async => order.add('channel'));
    when(
      () => push.initialize(any()),
    ).thenAnswer((_) async => order.add('initialize'));
    when(() => push.requestPermission()).thenAnswer((_) async => true);
    when(() => push.identify(any())).thenAnswer((_) async {});
    when(() => router.dispatchPending()).thenReturn(false);
    when(() => travelLocal.getActiveTravel()).thenAnswer((_) async => null);
    when(
      () => storage.saveTokens(any(), any(), any()),
    ).thenAnswer((_) async {});
    when(() => authLocal.updateTokens(any(), any())).thenAnswer((_) async {});
    when(
      () => signOut.signOut(message: any(named: 'message')),
    ).thenAnswer((_) async {});
    when(
      () => navigator.navigate(any(), arguments: any(named: 'arguments')),
    ).thenReturn(null);
    when(
      () => navigator.pushNamed(any(), arguments: any(named: 'arguments')),
    ).thenAnswer((_) async => null);

    Modular.init(
      _TestModule(
        authLocal: authLocal,
        datasource: datasource,
        storage: storage,
        signOut: signOut,
        travelLocal: travelLocal,
        dio: dio,
        push: push,
        router: router,
        channels: channels,
      ),
    );
    Modular.navigatorDelegate = navigator;
  });

  tearDown(() {
    Modular.navigatorDelegate = null;
    try {
      Modular.destroy();
    } catch (_) {}
    SessionReadiness.reset();
  });

  Future<void> pumpSplash(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SplashScreen(delay: Duration.zero)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  SignInResponseModel refreshed({String userId = 'user-1'}) =>
      SignInResponseModel(
        accessToken: 'new',
        refreshToken: 'new-refresh',
        expiresAt: DateTime(2026, 12, 1),
        refreshExpiresAt: DateTime(2027, 1, 1),
        userId: userId,
        roles: ['Passenger'],
      );

  // ─── Inicialização e permissão (1.1, 1.2, 1.7) ─────────────────────────

  group('inicialização do push', () {
    test('o identificador do OneSignal vem da configuração', () {
      expect(AppConfig.getOneSignalAppId(), 'app-xyz');
    });

    testWidgets(
      'inicializa com o identificador configurado e pede a permissão',
      (tester) async {
        when(() => authLocal.getAuth()).thenAnswer((_) async => null);
        when(() => storage.getToken()).thenAnswer((_) async => null);

        await pumpSplash(tester);

        verify(() => push.initialize('app-xyz')).called(1);
        verify(() => push.requestPermission()).called(1);
      },
    );

    testWidgets('a permissão só é pedida depois da inicialização', (
      tester,
    ) async {
      when(() => authLocal.getAuth()).thenAnswer((_) async => null);
      when(() => storage.getToken()).thenAnswer((_) async => null);
      final init = Completer<void>();
      when(() => push.initialize(any())).thenAnswer((_) => init.future);

      await pumpSplash(tester);
      verifyNever(() => push.requestPermission());

      init.complete();
      await tester.pump();
      await tester.pump();

      verify(() => push.requestPermission()).called(1);
    });

    testWidgets(
      'inicialização que não termina não atrasa a decisão de autenticação',
      (tester) async {
        when(() => authLocal.getAuth()).thenAnswer((_) async => null);
        when(() => storage.getToken()).thenAnswer((_) async => null);
        when(
          () => push.initialize(any()),
        ).thenAnswer((_) => Completer<void>().future);

        await pumpSplash(tester);

        verify(
          () =>
              navigator.navigate('/login', arguments: any(named: 'arguments')),
        ).called(1);
      },
    );

    testWidgets('falha do push na inicialização não impede o app de abrir', (
      tester,
    ) async {
      when(() => authLocal.getAuth()).thenAnswer((_) async => null);
      when(() => storage.getToken()).thenAnswer((_) async => null);
      when(() => push.initialize(any())).thenThrow(StateError('push quebrou'));

      await pumpSplash(tester);

      verify(
        () => navigator.navigate('/login', arguments: any(named: 'arguments')),
      ).called(1);
    });

    testWidgets('falha ao pedir a permissão não impede o app de abrir', (
      tester,
    ) async {
      when(() => authLocal.getAuth()).thenAnswer((_) async => null);
      when(() => storage.getToken()).thenAnswer((_) async => null);
      when(
        () => push.requestPermission(),
      ).thenThrow(StateError('permissão quebrou'));

      await pumpSplash(tester);

      verify(
        () => navigator.navigate('/login', arguments: any(named: 'arguments')),
      ).called(1);
    });
  });

  // ─── Identificação da sessão restaurada (2.2) ──────────────────────────

  // Canal de notificação (spec push-notification-sounds, req 2.1 e 2.5).
  group('canal de notificação no início do app', () {
    void stubNoSession() {
      when(() => authLocal.getAuth()).thenAnswer((_) async => null);
      when(() => storage.getToken()).thenAnswer((_) async => null);
    }

    testWidgets('cria o canal no início do app', (tester) async {
      stubNoSession();

      await pumpSplash(tester);

      verify(() => channels.ensureRideAlertsChannel()).called(1);
    });

    testWidgets('cria o canal ANTES de inicializar o OneSignal', (
      tester,
    ) async {
      stubNoSession();

      await pumpSplash(tester);

      expect(order.take(2).toList(), ['channel', 'initialize']);
    });

    testWidgets('falha ao criar o canal não impede o OneSignal nem o app', (
      tester,
    ) async {
      stubNoSession();
      when(
        () => channels.ensureRideAlertsChannel(),
      ).thenThrow(StateError('canal quebrou'));

      await pumpSplash(tester);

      verify(() => push.initialize('app-xyz')).called(1);
      verify(
        () => navigator.navigate('/login', arguments: any(named: 'arguments')),
      ).called(1);
    });

    testWidgets('canal que demora não atrasa a decisão de autenticação', (
      tester,
    ) async {
      stubNoSession();
      when(
        () => channels.ensureRideAlertsChannel(),
      ).thenAnswer((_) => Completer<void>().future);

      await pumpSplash(tester);

      verify(
        () => navigator.navigate('/login', arguments: any(named: 'arguments')),
      ).called(1);
    });
  });

  group('sessão restaurada identifica o aparelho', () {
    testWidgets('por renovação do token: usa o userId da renovação', (
      tester,
    ) async {
      when(() => authLocal.getAuth()).thenAnswer(
        (_) async => AuthLocalData(
          userId: 'antigo',
          accessToken: 'a',
          refreshToken: 'r',
          roles: ['Passenger'],
        ),
      );
      when(
        () => datasource.refreshToken('r'),
      ).thenAnswer((_) async => refreshed(userId: 'user-1'));

      await pumpSplash(tester);

      verify(() => push.identify('user-1')).called(1);
      verify(
        () => navigator.navigate(
          '/usage-terms-guard',
          arguments: any(named: 'arguments'),
        ),
      ).called(1);
    });

    testWidgets('por cache local sem refresh token: usa o userId do cache', (
      tester,
    ) async {
      when(() => authLocal.getAuth()).thenAnswer(
        (_) async => AuthLocalData(
          userId: 'user-cache',
          accessToken: 'a',
          roles: ['Passenger'],
        ),
      );

      await pumpSplash(tester);

      verify(() => push.identify('user-cache')).called(1);
    });

    testWidgets('por armazenamento seguro: usa o userId guardado', (
      tester,
    ) async {
      when(() => authLocal.getAuth()).thenAnswer((_) async => null);
      when(() => storage.getToken()).thenAnswer((_) async => 'token');
      when(() => storage.getUserId()).thenAnswer((_) async => 'user-secure');

      await pumpSplash(tester);

      verify(() => push.identify('user-secure')).called(1);
    });

    testWidgets(
      'armazenamento seguro sem userId não identifica, mas o app abre',
      (tester) async {
        when(() => authLocal.getAuth()).thenAnswer((_) async => null);
        when(() => storage.getToken()).thenAnswer((_) async => 'token');
        when(() => storage.getUserId()).thenAnswer((_) async => null);

        await pumpSplash(tester);

        verifyNever(() => push.identify(any()));
        verify(
          () => navigator.navigate(
            '/usage-terms-guard',
            arguments: any(named: 'arguments'),
          ),
        ).called(1);
      },
    );

    testWidgets('sem sessão não identifica e vai ao login', (tester) async {
      when(() => authLocal.getAuth()).thenAnswer((_) async => null);
      when(() => storage.getToken()).thenAnswer((_) async => null);

      await pumpSplash(tester);

      verifyNever(() => push.identify(any()));
      verify(
        () => navigator.navigate('/login', arguments: any(named: 'arguments')),
      ).called(1);
    });

    testWidgets('renovação recusada sai da sessão e não identifica', (
      tester,
    ) async {
      when(() => authLocal.getAuth()).thenAnswer(
        (_) async => AuthLocalData(
          userId: 'u',
          accessToken: 'a',
          refreshToken: 'r',
          roles: ['Passenger'],
        ),
      );
      when(
        () => datasource.refreshToken('r'),
      ).thenThrow(const UnauthorizedException());

      await pumpSplash(tester);

      verify(
        () => signOut.signOut(
          message: 'Sua sessão expirou, faça login novamente.',
        ),
      ).called(1);
      verifyNever(() => push.identify(any()));
    });

    testWidgets('falha de rede na renovação preserva a sessão', (tester) async {
      when(() => authLocal.getAuth()).thenAnswer(
        (_) async => AuthLocalData(
          userId: 'user-cache',
          accessToken: 'a',
          refreshToken: 'r',
          roles: ['Passenger'],
        ),
      );
      when(
        () => datasource.refreshToken('r'),
      ).thenThrow(const NetworkException());

      await pumpSplash(tester);

      verifyNever(
        () => signOut.signOut(message: any(named: 'message')),
      );
      verify(() => push.identify('user-cache')).called(1);
    });

    testWidgets('falha ao identificar não impede a navegação', (tester) async {
      when(() => authLocal.getAuth()).thenAnswer(
        (_) async => AuthLocalData(
          userId: 'user-cache',
          accessToken: 'a',
          roles: ['Passenger'],
        ),
      );
      when(
        () => push.identify(any()),
      ).thenThrow(StateError('identificar falhou'));

      await pumpSplash(tester);

      verify(
        () => navigator.navigate(
          '/usage-terms-guard',
          arguments: any(named: 'arguments'),
        ),
      ).called(1);
    });

    testWidgets(
      'a identificação não é esperada: identificar lento não atrasa a navegação',
      (tester) async {
        when(() => authLocal.getAuth()).thenAnswer(
          (_) async => AuthLocalData(
            userId: 'user-cache',
            accessToken: 'a',
            roles: ['Passenger'],
          ),
        );
        when(
          () => push.identify(any()),
        ).thenAnswer((_) => Completer<void>().future);

        await pumpSplash(tester);

        verify(
          () => navigator.navigate(
            '/usage-terms-guard',
            arguments: any(named: 'arguments'),
          ),
        ).called(1);
      },
    );
  });

  // ─── Toque guardado ao restaurar a viagem (5.2) ────────────────────────

  group('viagem ativa restaurada', () {
    TravelLocalData active(String status) => TravelLocalData(
      travelId: 'travel-1',
      status: status,
      createdAt: DateTime(2026, 10, 2),
    );

    void stubSession() {
      when(() => authLocal.getAuth()).thenAnswer(
        (_) async => AuthLocalData(
          userId: 'user-cache',
          accessToken: 'a',
          roles: ['Passenger'],
        ),
      );
    }

    testWidgets('restaura a viagem sem despachar uma segunda navegação', (
      tester,
    ) async {
      stubSession();
      when(
        () => travelLocal.getActiveTravel(),
      ).thenAnswer((_) async => active('Accepted'));
      when(() => dio.get(any())).thenAnswer(
        (_) async =>
            Response(requestOptions: RequestOptions(path: ''), statusCode: 200),
      );

      await pumpSplash(tester);

      verify(
        () => navigator.pushNamed(
          '/new-travel/tracking',
          arguments: any(named: 'arguments'),
        ),
      ).called(1);
      verifyNever(() => router.dispatchPending());
      expect(SessionReadiness.isReady, isTrue);
    });

    testWidgets(
      'sem viagem ativa não despacha: o toque espera a tela inicial',
      (tester) async {
        stubSession();

        await pumpSplash(tester);

        verifyNever(() => router.dispatchPending());
        expect(SessionReadiness.isReady, isFalse);
      },
    );

    testWidgets('viagem que não existe mais no backend não despacha', (
      tester,
    ) async {
      stubSession();
      when(
        () => travelLocal.getActiveTravel(),
      ).thenAnswer((_) async => active('Accepted'));
      when(() => dio.get(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 404,
          ),
        ),
      );
      when(() => travelLocal.clearTravels()).thenAnswer((_) async {});

      await pumpSplash(tester);

      verifyNever(() => router.dispatchPending());
    });

    testWidgets('falha no despacho não derruba a abertura do app', (
      tester,
    ) async {
      stubSession();
      when(
        () => travelLocal.getActiveTravel(),
      ).thenAnswer((_) async => active('Accepted'));
      when(() => dio.get(any())).thenAnswer(
        (_) async =>
            Response(requestOptions: RequestOptions(path: ''), statusCode: 200),
      );
      when(
        () => router.dispatchPending(),
      ).thenThrow(StateError('despacho falhou'));

      await pumpSplash(tester);

      verify(
        () => navigator.pushNamed(
          '/new-travel/tracking',
          arguments: any(named: 'arguments'),
        ),
      ).called(1);
    });
  });
}
