import 'dart:async';
import 'dart:developer';

import 'package:moto_passenger/core/notifications/i_push_notification_service.dart';
import 'package:moto_passenger/modules/auth/data/datasources/i_auth_datasource.dart';
import 'package:moto_passenger/modules/auth/domain/entities/password_policy_entity.dart';
import 'package:moto_passenger/modules/auth/domain/entities/user_entity.dart';
import 'package:moto_passenger/modules/auth/domain/repositories/i_auth_repository.dart';
import 'package:result_dart/result_dart.dart';

class AuthRepository implements IAuthRepository {
  final IAuthDatasource _datasource;
  final IPushNotificationService _push;

  AuthRepository(this._datasource, this._push);

  @override
  AsyncResult<UserEntity> signIn(
    String email,
    String password,
  ) async {
    try {
      final model = await _datasource.signIn(email, password);
      final user = model.toEntity();
      // Push (spec passenger-push-notifications): identifica o aparelho com o userId
      // do token, o mesmo que o backend usa para endereçar. Não espera nem afeta o login.
      unawaited(_identifyForPush(user.id));
      return Success(user);
    } on Exception catch (e) {
      return Failure(e);
    }
  }

  @override
  AsyncResult<UserEntity> refreshToken(String refreshToken) async {
    try {
      final model = await _datasource.refreshToken(refreshToken);
      return Success(model.toEntity());
    } on Exception catch (e) {
      return Failure(e);
    }
  }

  @override
  AsyncResult<Unit> requestPasswordReset(String email) async {
    try {
      await _datasource.requestPasswordReset(email);
      return Success(unit);
    } on Exception catch (e) {
      return Failure(e);
    }
  }

  @override
  AsyncResult<String> verifyPasswordResetCode({
    required String email,
    required String code,
  }) async {
    try {
      final resetToken = await _datasource.verifyPasswordResetCode(
        email: email,
        code: code,
      );
      return Success(resetToken);
    } on Exception catch (e) {
      return Failure(e);
    }
  }

  @override
  AsyncResult<Unit> confirmPasswordReset({
    required String resetToken,
    required String newPassword,
  }) async {
    try {
      await _datasource.confirmPasswordReset(
        resetToken: resetToken,
        newPassword: newPassword,
      );
      return Success(unit);
    } on Exception catch (e) {
      return Failure(e);
    }
  }

  @override
  AsyncResult<PasswordPolicy> getPasswordPolicy() async {
    try {
      final model = await _datasource.getPasswordPolicy();
      return Success(model.toEntity());
    } on Exception catch (e) {
      return Failure(e);
    }
  }

  Future<void> _identifyForPush(String userId) async {
    try {
      await _push.identify(userId);
    } catch (e) {
      log(
        '[PUSH] Identify after sign-in failed (${e.runtimeType}).',
        name: 'push',
        level: 900,
      );
    }
  }
}
