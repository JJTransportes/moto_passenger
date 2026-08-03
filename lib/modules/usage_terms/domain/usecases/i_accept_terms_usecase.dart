import 'package:result_dart/result_dart.dart';

abstract class IAcceptTermsUsecase {
  Future<Result<void>> call();
}
