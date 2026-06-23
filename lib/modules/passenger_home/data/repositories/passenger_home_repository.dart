import 'package:result_dart/result_dart.dart';
import 'package:moto_passenger/modules/passenger_home/data/datasources/i_passenger_home_datasource.dart';
import 'package:moto_passenger/modules/passenger_home/domain/entities/passenger_profile_entity.dart';
import 'package:moto_passenger/modules/passenger_home/domain/entities/travel_summary_entity.dart';
import 'package:moto_passenger/modules/passenger_home/domain/repositories/i_passenger_home_repository.dart';

class PassengerHomeRepository implements IPassengerHomeRepository {
  final IPassengerHomeDatasource _datasource;

  PassengerHomeRepository(this._datasource);

  @override
  AsyncResult<PassengerProfileEntity> getProfile() async {
    try {
      final model = await _datasource.getProfile();
      return Success(model.toEntity());
    } on Exception catch (e) {
      return Failure(e);
    }
  }

  @override
  AsyncResult<List<TravelSummaryEntity>> getActiveTravel() async {
    try {
      final result = await _datasource.getPassengerTravels(
        status: ['Accepted', 'InProgress'],
        pageSize: 1,
      );
      final entities = result.items.map((m) => m.toEntity()).toList();
      return Success(entities);
    } on Exception catch (e) {
      return Failure(e);
    }
  }

  @override
  AsyncResult<List<TravelSummaryEntity>> getLastTravels({
    int page = 1,
    int pageSize = 5,
  }) async {
    try {
      final result = await _datasource.getPassengerTravels(
        status: ['Completed', 'Cancelled'],
        page: page,
        pageSize: pageSize,
      );
      final entities = result.items.map((m) => m.toEntity()).toList();
      return Success(entities);
    } on Exception catch (e) {
      return Failure(e);
    }
  }
}
