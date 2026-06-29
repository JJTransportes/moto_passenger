import 'package:moto_passenger/modules/passenger_registration/data/repositories/i_registration_repository.dart';
import 'package:moto_passenger/modules/passenger_registration/domain/entities/register_passenger_request.dart';
import 'package:moto_passenger/modules/passenger_registration/domain/usecases/i_register_usecase.dart';
import 'package:result_dart/result_dart.dart';

class RegisterUsecase implements IRegisterUsecase {
  final IRegistrationRepository _repository;

  RegisterUsecase(this._repository);

  @override
  AsyncResult<String> call(RegisterPassengerRequest request) {
    return _repository.register(request);
  }
}
