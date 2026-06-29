import 'package:result_dart/result_dart.dart';
import 'package:moto_passenger/modules/passenger_registration/domain/entities/public_partition_entity.dart';
import 'package:moto_passenger/modules/passenger_registration/domain/entities/register_passenger_request.dart';

abstract class IRegistrationRepository {
  Future<Result<List<PublicPartition>>> getPublicPartitions();

  Future<Result<String>> register(RegisterPassengerRequest request);
}
