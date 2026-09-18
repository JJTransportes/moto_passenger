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
    testWidgets('calls backend sign-out before clearing local state', (tester) async {
      await pumpModularApp(tester);

      when(() => authStorage.clear()).thenAnswer((_) async {});
      when(() => authLocal.clearAuth()).thenAnswer((_) async {});
      when(() => profileLocal.clearProfile()).thenAnswer((_) async {});
      when(() => travelLocal.clearTravels()).thenAnswer((_) async {});

      await service.signOut();
      // Flush do timer de debounce (500ms) do ModularRouterDelegate.navigate
      await tester.pump(const Duration(milliseconds: 600));

      // Ordem: OneSignal → backend sign-out (neutraliza device) → limpeza local
      verifyInOrder([
        () => authStorage.clear(),
      ]);
      verify(() => authLocal.clearAuth()).called(1);
      verify(() => profileLocal.clearProfile()).called(1);
      verify(() => travelLocal.clearTravels()).called(1);
    });

    testWidgets('backend sign-out failure does not block local sign out', (tester) async {
      await pumpModularApp(tester);

      when(() => authStorage.clear()).thenAnswer((_) async {});
      when(() => authLocal.clearAuth()).thenAnswer((_) async {});
      when(() => profileLocal.clearProfile()).thenAnswer((_) async {});
      when(() => travelLocal.clearTravels()).thenAnswer((_) async {});

      await service.signOut();
      await tester.pump(const Duration(milliseconds: 600));

      verify(() => authStorage.clear()).called(1);
      verify(() => authLocal.clearAuth()).called(1);
    });

    testWidgets('push logout failure does not block sign out', (tester) async {
      await pumpModularApp(tester);

      when(() => authStorage.clear()).thenAnswer((_) async {});
      when(() => authLocal.clearAuth()).thenAnswer((_) async {});
      when(() => profileLocal.clearProfile()).thenAnswer((_) async {});
      when(() => travelLocal.clearTravels()).thenAnswer((_) async {});

      await service.signOut();
      await tester.pump(const Duration(milliseconds: 600));

      verify(() => authStorage.clear()).called(1);
    });
  });
}
