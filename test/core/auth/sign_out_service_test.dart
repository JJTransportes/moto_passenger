import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_passenger/core/auth/auth_storage.dart';
import 'package:moto_passenger/core/auth/sign_out_service.dart';
import 'package:moto_passenger/core/local_db/repositories/auth_local_repository.dart';
import 'package:moto_passenger/core/local_db/repositories/profile_local_repository.dart';
import 'package:moto_passenger/core/local_db/repositories/travel_local_repository.dart';
import 'package:moto_passenger/core/notifications/i_push_notification_service.dart';
import 'package:moto_passenger/core/notifications/session_readiness.dart';

class MockAuthStorage extends Mock implements AuthStorage {}

class MockAuthLocalRepository extends Mock implements AuthLocalRepository {}

class MockProfileLocalRepository extends Mock implements ProfileLocalRepository {}

class MockTravelLocalRepository extends Mock implements TravelLocalRepository {}

class MockPushNotificationService extends Mock implements IPushNotificationService {}

class _TestModule extends Module {
  @override
  void routes(RouteManager r) {
    r.child('/', child: (_) => const Scaffold(body: SizedBox()));
    r.child('/login', child: (_) => const Scaffold(body: SizedBox()));
  }
}

void main() {
  late MockAuthStorage authStorage;
  late MockAuthLocalRepository authLocal;
  late MockProfileLocalRepository profileLocal;
  late MockTravelLocalRepository travelLocal;
  late MockPushNotificationService push;
  late SignOutService service;

  setUp(() {
    authStorage = MockAuthStorage();
    authLocal = MockAuthLocalRepository();
    profileLocal = MockProfileLocalRepository();
    travelLocal = MockTravelLocalRepository();
    push = MockPushNotificationService();
    when(() => push.clear()).thenAnswer((_) async {});

    service = SignOutService(
      authStorage,
      authLocal,
      profileLocal,
      travelLocal,
      push,
    );
  });

  tearDown(() {
    cleanModular();
  });

  Future<void> pumpModularApp(WidgetTester tester) async {
    Modular.init(_TestModule());
    await tester.pumpWidget(
      MaterialApp.router(
        routeInformationParser: Modular.routeInformationParser,
        routerDelegate: Modular.routerDelegate,
      ),
    );
    await tester.pump();
  }

  group('SignOutService.signOut', () {
    testWidgets('clears all local state and navigates to /login', (tester) async {
      await pumpModularApp(tester);

      when(() => authStorage.clear()).thenAnswer((_) async {});
      when(() => authLocal.clearAuth()).thenAnswer((_) async {});
      when(() => profileLocal.clearProfile()).thenAnswer((_) async {});
      when(() => travelLocal.clearTravels()).thenAnswer((_) async {});

      await service.signOut();
      // Flush do timer de debounce (500ms) do ModularRouterDelegate.navigate
      await tester.pump(const Duration(milliseconds: 600));

      // PSG-11: `signOut()` limpa o storage e o banco locais, remove a identificação
      // do aparelho no push (spec passenger-push-notifications, req 2.3) e navega
      // para `/login`; não há chamada de backend de sign-out aqui.
      verify(() => authStorage.clear()).called(1);
      verify(() => authLocal.clearAuth()).called(1);
      verify(() => profileLocal.clearProfile()).called(1);
      verify(() => travelLocal.clearTravels()).called(1);
    });

    testWidgets('clears all local state exactly once per call', (tester) async {
      await pumpModularApp(tester);

      when(() => authStorage.clear()).thenAnswer((_) async {});
      when(() => authLocal.clearAuth()).thenAnswer((_) async {});
      when(() => profileLocal.clearProfile()).thenAnswer((_) async {});
      when(() => travelLocal.clearTravels()).thenAnswer((_) async {});

      await service.signOut();
      await tester.pump(const Duration(milliseconds: 600));

      verify(() => authStorage.clear()).called(1);
      verify(() => authLocal.clearAuth()).called(1);
      verify(() => profileLocal.clearProfile()).called(1);
      verify(() => travelLocal.clearTravels()).called(1);
    });
  });

  // Spec passenger-push-notifications (req 2.3, 2.4, 2.5, 4.6, 7.1).
  group('SignOutService.signOut e o push', () {
    void stubLocalClears() {
      when(() => authStorage.clear()).thenAnswer((_) async {});
      when(() => authLocal.clearAuth()).thenAnswer((_) async {});
      when(() => profileLocal.clearProfile()).thenAnswer((_) async {});
      when(() => travelLocal.clearTravels()).thenAnswer((_) async {});
    }

    testWidgets('remove a identificação do aparelho no push', (tester) async {
      await pumpModularApp(tester);
      stubLocalClears();

      await service.signOut();
      await tester.pump(const Duration(milliseconds: 600));

      verify(() => push.clear()).called(1);
    });

    testWidgets('a sessão deixa de estar pronta para abrir notificações', (tester) async {
      await pumpModularApp(tester);
      stubLocalClears();
      SessionReadiness.markReady();

      await service.signOut();
      await tester.pump(const Duration(milliseconds: 600));

      expect(SessionReadiness.isReady, isFalse);
    });

    testWidgets('falha do push não impede a limpeza local nem a ida ao login', (tester) async {
      await pumpModularApp(tester);
      stubLocalClears();
      when(() => push.clear()).thenThrow(StateError('push falhou'));

      await service.signOut();
      await tester.pump(const Duration(milliseconds: 600));

      verify(() => authStorage.clear()).called(1);
      verify(() => authLocal.clearAuth()).called(1);
      verify(() => profileLocal.clearProfile()).called(1);
      verify(() => travelLocal.clearTravels()).called(1);
    });

    testWidgets('push que demora demais não trava a saída de sessão', (tester) async {
      await pumpModularApp(tester);
      stubLocalClears();
      when(() => push.clear()).thenAnswer((_) => Completer<void>().future); // nunca termina
      final slowService = SignOutService(
        authStorage,
        authLocal,
        profileLocal,
        travelLocal,
        push,
        pushTimeout: const Duration(milliseconds: 30),
      );

      await tester.runAsync(() => slowService.signOut().timeout(const Duration(seconds: 2)));
      await tester.pump(const Duration(milliseconds: 600));

      verify(() => authStorage.clear()).called(1);
    });

    testWidgets('a exclusão de conta (que usa o signOut) também remove a identificação', (tester) async {
      await pumpModularApp(tester);
      stubLocalClears();

      // DeleteAccountUsecase chama `SignOutService.signOut()` ao concluir.
      await service.signOut();
      await tester.pump(const Duration(milliseconds: 600));

      verify(() => push.clear()).called(1);
    });
  });
}
