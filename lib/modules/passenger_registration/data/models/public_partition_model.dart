import 'package:moto_passenger/modules/passenger_registration/domain/entities/department_entity.dart';
import 'package:moto_passenger/modules/passenger_registration/domain/entities/public_partition_entity.dart';

class DepartmentModel {
  final String departmentId;
  final String name;

  const DepartmentModel({
    required this.departmentId,
    required this.name,
  });

  factory DepartmentModel.fromJson(Map<String, dynamic> json) {
    return DepartmentModel(
      departmentId: json['departmentId'] as String,
      name: json['name'] as String,
    );
  }

  Department toEntity() {
    return Department(
      departmentId: departmentId,
      name: name,
    );
  }
}

class PublicPartitionModel {
  final String partitionId;
  final String name;
  final String acronym;
  final List<DepartmentModel> departments;

  const PublicPartitionModel({
    required this.partitionId,
    required this.name,
    required this.acronym,
    required this.departments,
  });

  factory PublicPartitionModel.fromJson(Map<String, dynamic> json) {
    return PublicPartitionModel(
      partitionId: json['partitionId'] as String,
      name: json['name'] as String,
      acronym: json['acronym'] as String,
      departments: (json['departments'] as List<dynamic>?)
              ?.map(
                  (d) => DepartmentModel.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  PublicPartition toEntity() {
    return PublicPartition(
      partitionId: partitionId,
      name: name,
      acronym: acronym,
      departments: departments.map((d) => d.toEntity()).toList(),
    );
  }
}
