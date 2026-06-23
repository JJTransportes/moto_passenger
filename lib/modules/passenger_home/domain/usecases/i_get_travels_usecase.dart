import 'package:result_dart/result_dart.dart';
import 'package:moto_passenger/modules/passenger_home/domain/entities/travel_summary_entity.dart';

abstract class IGetActiveTravelUsecase {
  AsyncResult<List<TravelSummaryEntity>> call();
}

abstract class IGetLastTravelsUsecase {
  AsyncResult<List<TravelSummaryEntity>> call({
    int page = 1,
    int pageSize = 5,
  });
}
