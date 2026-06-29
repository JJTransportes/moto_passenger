import 'package:moto_passenger/modules/passenger_registration/data/datasources/i_registration_datasource.dart';
import 'package:moto_passenger/modules/passenger_registration/data/models/public_partition_model.dart';
import 'package:moto_passenger/modules/passenger_registration/data/repositories/i_registration_repository.dart';
import 'package:moto_passenger/modules/passenger_registration/domain/entities/public_partition_entity.dart';
import 'package:moto_passenger/modules/passenger_registration/domain/entities/register_passenger_request.dart';
import 'package:result_dart/result_dart.dart';

class RegistrationRepository implements IRegistrationRepository {
  final IRegistrationDatasource _datasource;

  RegistrationRepository(this._datasource);

  @override
  AsyncResult<List<PublicPartition>> getPublicPartitions() async {
    try {
      final rawList = await _datasource.getPublicPartitions();
      final partitions = rawList
          .map((json) =>
              PublicPartitionModel.fromJson(json).toEntity())
          .toList();
      return Success(partitions);
    } on Exception catch (e) {
      return Failure(e);
    }
  }

  @override
  AsyncResult<String> register(RegisterPassengerRequest request) async {
    try {
      final response = await _datasource.selfRegister(request.toJson());
      final registrationId = response['registrationId'] as String;
      return Success(registrationId);
    } on Exception catch (e) {
      return Failure(e);
    }
  }
}
