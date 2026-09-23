import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_passenger/modules/auth/domain/entities/user_entity.dart';
import 'package:moto_passenger/modules/auth/presentation/blocs/login_bloc.dart';
import 'package:moto_passenger/modules/auth/presentation/pages/login_page.dart';
import 'package:moto_passenger/widgets/app_button.dart';

// LoginPage needs two separate ways of resolving LoginBloc:
// - BlocConsumer<LoginBloc, LoginState> uses flutter_bloc's own context.read,
//   which needs a BlocProvider ancestor.
// - _submit() calls context.read<LoginBloc>() too, but the file imports
//   flutter_bloc with `hide ReadContext`, so that call resolves to
//   flutter_modular's ModularWatchExtension instead — it needs a real
//   ModularApp ancestor with LoginBloc bound in the injector.
// Both wrappers are required for the widget to work in a test.
class _LoginTestModule extends Module {
  final LoginBloc bloc;

  _LoginTestModule(this.bloc);

  @override
  void binds(Injector i) {
    i.addInstance<LoginBloc>(bloc);
  }
}

void main() {
  late MockLoginBloc mockBloc;

  setUp(() {
    mockBloc = MockLoginBloc();
  });

  tearDown(() {
    try {
      Modular.destroy();
    } catch (_) {}
  });

  Widget buildWidget() => ModularApp(
    module: _LoginTestModule(mockBloc),
    child: MaterialApp(
      routes: {
        '/home': (_) => const Scaffold(body: Text('Home')),
        '/recovery': (_) => const Scaffold(body: Text('Recovery')),
        '/usage-terms-guard': (_) => const Scaffold(body: Text('UsageTermsGuard')),
      },
      home: BlocProvider<LoginBloc>.value(
        value: mockBloc,
        child: const LoginPage(),
      ),
    ),
  );

  testWidgets('shows app title', (tester) async {
    when(() => mockBloc.state).thenReturn(const LoginInitial());

    await tester.pumpWidget(buildWidget());

    expect(find.text('App Passageiro'), findsOneWidget);
  });

  testWidgets('shows email and password fields', (tester) async {
    when(() => mockBloc.state).thenReturn(const LoginInitial());

    await tester.pumpWidget(buildWidget());

    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
  });

  testWidgets('shows Entrar button', (tester) async {
    when(() => mockBloc.state).thenReturn(const LoginInitial());

    await tester.pumpWidget(buildWidget());

    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('shows Esqueci minha senha link', (tester) async {
    when(() => mockBloc.state).thenReturn(const LoginInitial());

    await tester.pumpWidget(buildWidget());

    expect(find.text('Esqueci minha senha'), findsOneWidget);
  });

  // Regra de negócio: o botão "Entrar" fica desabilitado enquanto o
  // formulário não estiver completo (_isFormFilled) — por isso não dá pra
  // "tocar no botão vazio" para revelar as mensagens de campo obrigatório;
  // o teste correto é verificar que o botão continua desabilitado.
  testWidgets('Entrar button stays disabled with empty email', (tester) async {
    when(() => mockBloc.state).thenReturn(const LoginInitial());

    await tester.pumpWidget(buildWidget());

    final button = tester.widget<AppButton>(find.byType(AppButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('Entrar button stays disabled with empty password', (tester) async {
    when(() => mockBloc.state).thenReturn(const LoginInitial());

    await tester.pumpWidget(buildWidget());

    await tester.enterText(
      find.widgetWithText(TextField, 'Informe seu e-mail'),
      'passenger@moto.com',
    );
    await tester.pump();

    final button = tester.widget<AppButton>(find.byType(AppButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('adds LoginSubmitted event on form submit', (tester) async {
    when(() => mockBloc.state).thenReturn(const LoginInitial());

    await tester.pumpWidget(buildWidget());

    await tester.enterText(
      find.widgetWithText(TextField, 'Informe seu e-mail'),
      'passenger@moto.com',
    );
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'Informe sua senha'),
      'secret123',
    );
    await tester.pump();
    final entrarButton = find.text('Entrar');
    await tester.ensureVisible(entrarButton);
    await tester.tap(entrarButton);
    await tester.pump();

    verify(
      () => mockBloc.add(
        const LoginSubmitted(
          email: 'passenger@moto.com',
          password: 'secret123',
        ),
      ),
    ).called(1);
  });

  testWidgets('shows loading indicator while loading', (tester) async {
    when(() => mockBloc.state).thenReturn(const LoginLoading());

    await tester.pumpWidget(buildWidget());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows error message on failure', (tester) async {
    when(() => mockBloc.state).thenReturn(const LoginFailure('E-mail ou senha inválidos'));

    await tester.pumpWidget(buildWidget());

    expect(find.text('E-mail ou senha inválidos'), findsOneWidget);
  });

  testWidgets('navigates to usage-terms-guard on success', (tester) async {
    // BlocListener reacts to stream emissions, not to the `.state` getter —
    // setting `.state` directly never triggers navigation. whenListen
    // (bloc_test) stubs the stream properly, matching MockBloc's pattern.
    const successUser = UserEntity(
      id: 'u1',
      token: 'tok',
      roles: ['Passenger'],
    );
    whenListen(
      mockBloc,
      Stream.fromIterable([LoginSuccess(successUser)]),
      initialState: const LoginInitial(),
    );

    await tester.pumpWidget(buildWidget());
    await tester.pumpAndSettle();

    expect(find.text('UsageTermsGuard'), findsOneWidget);
  });

  testWidgets('navigates to recovery screen on forgot password tap', (tester) async {
    when(() => mockBloc.state).thenReturn(const LoginInitial());

    await tester.pumpWidget(buildWidget());

    await tester.tap(find.text('Esqueci minha senha'));
    await tester.pumpAndSettle();

    expect(find.text('Recovery'), findsOneWidget);
  });
}

class MockLoginBloc extends MockBloc<LoginEvent, LoginState> implements LoginBloc {}
