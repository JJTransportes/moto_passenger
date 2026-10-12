import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_passenger/core/auth/auth_storage.dart';
import 'package:moto_passenger/core/auth/sign_out_service.dart';
import 'package:moto_passenger/core/errors/exceptions.dart';
import 'package:moto_passenger/core/http/dio_client.dart';
import 'package:moto_passenger/core/local_db/repositories/auth_local_repository.dart';
import 'package:moto_passenger/modules/auth/data/datasources/i_auth_datasource.dart';

class _MockAuthStorage extends Mock implements AuthStorage {}

class _MockAuthDatasource extends Mock implements IAuthDatasource {}

class _MockAuthLocalRepository extends Mock implements AuthLocalRepository {}

class _MockSignOutService extends Mock implements SignOutService {}

class _TestModule extends Module {
  _TestModule(this.storage, this.datasource, this.local, this.signOut);

  final AuthStorage storage;
  final IAuthDatasource datasource;
  final AuthLocalRepository local;
  final SignOutService signOut;

  @override
  void binds(i) {
    i.addInstance<AuthStorage>(storage);
    i.addInstance<IAuthDatasource>(datasource);
    i.addInstance<AuthLocalRepository>(local);
    i.addInstance<SignOutService>(signOut);
  }
}

class _UnauthorizedAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString('{"error":"unauthorized"}', 401);
}

void main() {
  late _MockAuthStorage storage;
  late _MockAuthDatasource datasource;
  late _MockAuthLocalRepository local;
  late _MockSignOutService signOut;

  setUp(() {
    storage = _MockAuthStorage();
    datasource = _MockAuthDatasource();
    local = _MockAuthLocalRepository();
    signOut = _MockSignOutService();
    when(() => storage.getRefreshToken()).thenAnswer((_) async => 'refresh');
    when(
      () => signOut.signOut(message: any(named: 'message')),
    ).thenAnswer((_) async {});
    Modular.init(_TestModule(storage, datasource, local, signOut));
  });

  tearDown(Modular.destroy);

  Dio buildDio() {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = _UnauthorizedAdapter();
    dio.interceptors.add(AuthErrorInterceptor());
    return dio;
  }

  test('falha temporária no refresh preserva a sessão', () async {
    when(
      () => datasource.refreshToken('refresh'),
    ).thenThrow(const NetworkException());

    await expectLater(
      buildDio().get('/protected'),
      throwsA(isA<DioException>()),
    );

    verifyNever(() => signOut.signOut(message: any(named: 'message')));
  });

  test('refresh token confirmado como inválido encerra a sessão', () async {
    when(
      () => datasource.refreshToken('refresh'),
    ).thenThrow(const ValidationException('Token expirado.'));

    await expectLater(
      buildDio().get('/protected'),
      throwsA(isA<DioException>()),
    );

    verify(
      () => signOut.signOut(
        message: 'Sua sessão expirou, faça login novamente.',
      ),
    ).called(1);
  });
}
