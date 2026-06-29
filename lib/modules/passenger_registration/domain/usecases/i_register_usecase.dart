import 'package:result_dart/result_dart.dart';
import 'package:moto_passenger/modules/passenger_registration/domain/entities/register_passenger_request.dart';

abstract class IRegisterUsecase {
  Future<Result<String>> call(RegisterPassengerRequest request);
}
