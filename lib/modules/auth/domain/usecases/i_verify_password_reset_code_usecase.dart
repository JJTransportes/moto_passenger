import 'package:result_dart/result_dart.dart';

abstract class IVerifyPasswordResetCodeUsecase {
  AsyncResult<String> call({
    required String email,
    required String code,
  });
}
