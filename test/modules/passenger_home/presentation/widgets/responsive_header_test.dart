import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_passenger/core/auth/auth_storage.dart';
import 'package:moto_passenger/design_system/design_system.dart';
import 'package:moto_passenger/modules/passenger_home/presentation/widgets/profile_header.dart';

class _MockAuthStorage extends Mock implements AuthStorage {}

class _ResponsiveTestModule extends Module {
  _ResponsiveTestModule(this.authStorage);

  final AuthStorage authStorage;

  @override
  void binds(Injector i) {
    i.addInstance<AuthStorage>(authStorage);
  }
}

void main() {
  for (final viewport in <({String name, Size size, double textScale})>[
    (name: 'iPhone SE', size: const Size(320, 568), textScale: 1.3),
    (name: 'iPhone moderno', size: const Size(390, 844), textScale: 1.0),
    (name: 'Android grande', size: const Size(430, 932), textScale: 1.0),
  ]) {
    testWidgets(
      'cabeçalho e status não causam overflow em ${viewport.name}',
      (tester) async {
        final authStorage = _MockAuthStorage();
        when(() => authStorage.getToken()).thenAnswer((_) async => null);
        Modular.init(_ResponsiveTestModule(authStorage));
        addTearDown(Modular.destroy);

        await tester.binding.setSurfaceSize(viewport.size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            theme: MotoTheme.claro(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(viewport.textScale),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: const [
                      ProfileHeader(
                        fullName: 'Alexandre Passageiro Com Nome Extenso',
                      ),
                      SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: MotoStatusBadge(
                          label: 'Aceita · aguardando motorista',
                          tone: MotoTone.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.textContaining('Olá, Alexandre'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
