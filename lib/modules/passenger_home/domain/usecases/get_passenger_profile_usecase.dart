import 'package:result_dart/result_dart.dart';
import 'package:moto_passenger/modules/passenger_home/domain/entities/passenger_profile_entity.dart';
import 'package:moto_passenger/modules/passenger_home/domain/repositories/i_passenger_home_repository.dart';
import 'package:moto_passenger/modules/passenger_home/domain/usecases/i_get_passenger_profile_usecase.dart';

class GetPassengerProfileUsecase implements IGetPassengerProfileUsecase {
  final IPassengerHomeRepository _repository;

  GetPassengerProfileUsecase(this._repository);

  @override
  AsyncResult<PassengerProfileEntity> call() {
    return _repository.getProfile();
  }
}
