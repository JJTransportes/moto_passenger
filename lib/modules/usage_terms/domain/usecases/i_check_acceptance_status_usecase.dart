import 'package:result_dart/result_dart.dart';
import 'package:moto_passenger/modules/usage_terms/domain/entities/usage_term_entity.dart';

abstract class ICheckAcceptanceStatusUsecase {
  Future<Result<AcceptanceStatusEntity>> call();
}
