import 'package:result_dart/result_dart.dart';
import 'package:moto_passenger/modules/passenger_home/domain/entities/passenger_profile_entity.dart';
import 'package:moto_passenger/modules/passenger_home/domain/entities/travel_summary_entity.dart';

abstract class IPassengerHomeRepository {
  AsyncResult<PassengerProfileEntity> getProfile();
  AsyncResult<List<TravelSummaryEntity>> getActiveTravel();
  AsyncResult<List<TravelSummaryEntity>> getLastTravels({
    int page = 1,
    int pageSize = 5,
  });
}
