import 'package:result_dart/result_dart.dart';
import 'package:moto_passenger/modules/usage_terms/data/repositories/i_usage_terms_repository.dart';
import 'package:moto_passenger/modules/usage_terms/domain/usecases/i_accept_terms_usecase.dart';

class AcceptTermsUsecase implements IAcceptTermsUsecase {
  final IUsageTermsRepository _repository;

  AcceptTermsUsecase(this._repository);

  @override
  Future<Result<void>> call() {
    return _repository.acceptTerms();
  }
}
