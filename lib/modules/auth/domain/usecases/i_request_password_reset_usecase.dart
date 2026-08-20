import 'package:result_dart/result_dart.dart';

abstract class IRequestPasswordResetUsecase {
  AsyncResult<Unit> call(String email);
}
