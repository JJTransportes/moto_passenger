// Identificação no push ao entrar (spec passenger-push-notifications, req 2.1, 2.6,
// 7.1 e 7.2): o login identifica o aparelho com o userId e nunca é afetado pelo push.
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_passenger/core/errors/exceptions.dart';
import 'package:moto_passenger/core/notifications/i_push_notification_service.dart';
import 'package:moto_passenger/modules/auth/data/datasources/i_auth_datasource.dart';
import 'package:moto_passenger/modules/auth/data/models/sign_in_response_model.dart';
import 'package:moto_passenger/modules/auth/data/repositories/auth_repository.dart';

class MockAuthDatasource extends Mock implements IAuthDatasource {}

class MockPushNotificationService extends Mock implements IPushNotificationService {}

void main() {
  late MockAuthDatasource datasource;
  late MockPushNotificationService push;
  late AuthRepository repository;

  final model = SignInResponseModel(
    accessToken: 'tok_123',
    expiresAt: DateTime(2026, 6, 9, 0, 15),
    userId: 'user_1',
    roles: ['Passenger'],
  );

  setUp(() {
    datasource = MockAuthDatasource();
    push = MockPushNotificationService();
    repository = AuthRepository(datasource, push);
    when(() => push.identify(any())).thenAnswer((_) async {});
  });

  test('login com sucesso identifica o aparelho com o userId', () async {
    when(() => datasource.signIn(any(), any())).thenAnswer((_) async => model);

    final result = await repository.signIn('maria@moto.com', '123456');

    expect(result.isSuccess(), isTrue);
    verify(() => push.identify('user_1')).called(1);
  });

  test('o userId usado é o mesmo que o backend usa para endereçar (o do token)', () async {
    when(() => datasource.signIn(any(), any())).thenAnswer((_) async => model);

    final result = await repository.signIn('maria@moto.com', '123456');

    verify(() => push.identify(result.getOrNull()!.id)).called(1);
  });

  test('login que falha não identifica ninguém', () async {
    when(() => datasource.signIn(any(), any())).thenThrow(const UnauthorizedException());

    final result = await repository.signIn('maria@moto.com', 'errada');

    expect(result.isError(), isTrue);
    verifyNever(() => push.identify(any()));
  });

  test('falha do serviço de push não altera o resultado do login', () async {
    when(() => datasource.signIn(any(), any())).thenAnswer((_) async => model);
    when(() => push.identify(any())).thenThrow(StateError('push indisponível'));

    final result = await repository.signIn('maria@moto.com', '123456');

    expect(result.isSuccess(), isTrue);
    expect(result.getOrNull()!.id, 'user_1');
  });

  test('o login não espera a identificação terminar', () async {
    when(() => datasource.signIn(any(), any())).thenAnswer((_) async => model);
    when(() => push.identify(any())).thenAnswer((_) => Future<void>.delayed(const Duration(seconds: 30)));

    final result = await repository.signIn('maria@moto.com', '123456').timeout(const Duration(seconds: 2));

    expect(result.isSuccess(), isTrue);
  });
}
