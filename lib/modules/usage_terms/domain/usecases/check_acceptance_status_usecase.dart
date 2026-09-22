import 'package:result_dart/result_dart.dart';
import 'package:moto_passenger/modules/usage_terms/data/repositories/i_usage_terms_repository.dart';
import 'package:moto_passenger/modules/usage_terms/domain/entities/usage_term_entity.dart';
import 'package:moto_passenger/modules/usage_terms/domain/usecases/i_check_acceptance_status_usecase.dart';

class CheckAcceptanceStatusUsecase implements ICheckAcceptanceStatusUsecase {
  final IUsageTermsRepository _repository;

  CheckAcceptanceStatusUsecase(this._repository);

  @override
  Future<Result<AcceptanceStatusEntity>> call() {
    return _repository.checkAcceptanceStatus();
  }
}
