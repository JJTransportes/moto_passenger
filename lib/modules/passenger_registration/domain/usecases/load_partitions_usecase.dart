import 'package:moto_passenger/modules/passenger_registration/data/repositories/i_registration_repository.dart';
import 'package:moto_passenger/modules/passenger_registration/domain/entities/public_partition_entity.dart';
import 'package:moto_passenger/modules/passenger_registration/domain/usecases/i_load_partitions_usecase.dart';
import 'package:result_dart/result_dart.dart';

class LoadPartitionsUsecase implements ILoadPartitionsUsecase {
  final IRegistrationRepository _repository;

  LoadPartitionsUsecase(this._repository);

  @override
  AsyncResult<List<PublicPartition>> call() {
    return _repository.getPublicPartitions();
  }
}
