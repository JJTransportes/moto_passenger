import 'package:result_dart/result_dart.dart';
import 'package:moto_passenger/modules/passenger_home/domain/entities/passenger_profile_entity.dart';

abstract class IGetPassengerProfileUsecase {
  AsyncResult<PassengerProfileEntity> call();
}
