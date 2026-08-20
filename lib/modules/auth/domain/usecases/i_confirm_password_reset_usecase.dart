import 'package:result_dart/result_dart.dart';

abstract class IConfirmPasswordResetUsecase {
  AsyncResult<Unit> call({
    required String email,
    required String code,
    required String newPassword,
  });
}
