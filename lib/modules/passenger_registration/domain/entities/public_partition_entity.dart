import 'department_entity.dart';

class PublicPartition {
  final String partitionId;
  final String name;
  final String acronym;
  final List<Department> departments;

  const PublicPartition({
    required this.partitionId,
    required this.name,
    required this.acronym,
    required this.departments,
  });
}
