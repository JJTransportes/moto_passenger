import 'package:result_dart/result_dart.dart';
import 'package:moto_passenger/modules/passenger_home/domain/entities/travel_summary_entity.dart';
import 'package:moto_passenger/modules/passenger_home/domain/repositories/i_passenger_home_repository.dart';
import 'package:moto_passenger/modules/passenger_home/domain/usecases/i_get_travels_usecase.dart';

class GetActiveTravelUsecase implements IGetActiveTravelUsecase {
  final IPassengerHomeRepository _repository;

  GetActiveTravelUsecase(this._repository);

  @override
  AsyncResult<List<TravelSummaryEntity>> call() {
    return _repository.getActiveTravel();
  }
}

class GetLastTravelsUsecase implements IGetLastTravelsUsecase {
  final IPassengerHomeRepository _repository;

  GetLastTravelsUsecase(this._repository);

  @override
  AsyncResult<List<TravelSummaryEntity>> call({
    int page = 1,
    int pageSize = 5,
  }) {
    return _repository.getLastTravels(page: page, pageSize: pageSize);
  }
}
