import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_passenger/core/auth/auth_storage.dart';
import 'package:moto_passenger/core/auth/sign_out_service.dart';
import 'package:moto_passenger/core/local_db/repositories/auth_local_repository.dart';
import 'package:moto_passenger/core/local_db/repositories/profile_local_repository.dart';
import 'package:moto_passenger/core/local_db/repositories/travel_local_repository.dart';

class MockAuthStorage extends Mock implements AuthStorage {}

class MockAuthLocalRepository extends Mock implements AuthLocalRepository {}

class MockProfileLocalRepository extends Mock implements ProfileLocalRepository {}

class MockTravelLocalRepository extends Mock implements TravelLocalRepository {}

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
  late SignOutService service;

  setUp(() {
    authStorage = MockAuthStorage();
    authLocal = MockAuthLocalRepository();
    profileLocal = MockProfileLocalRepository();
    travelLocal = MockTravelLocalRepository();

    service = SignOutService(
      authStorage,
      authLocal,
      profileLocal,
      travelLocal,
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

      // PSG-11: `signOut()` é 100% local (limpa `AuthStorage`/
      // `AuthLocalRepository`/`ProfileLocalRepository`/`TravelLocalRepository`
      // e navega pra `/login`) — não há chamada de backend nem de push aqui.
      // O app passageiro nunca integrou o OneSignal de verdade (decisão de
      // 24/09/2026, ver PSG-05 no CHECKLIST-MASTER.md); os comentários e
      // nomes de teste antigos ("OneSignal → backend sign-out") descreviam
      // um fluxo que nunca existiu neste serviço.
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
}
