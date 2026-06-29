import 'package:result_dart/result_dart.dart';
import 'package:moto_passenger/modules/passenger_registration/domain/entities/public_partition_entity.dart';

abstract class ILoadPartitionsUsecase {
  Future<Result<List<PublicPartition>>> call();
}
