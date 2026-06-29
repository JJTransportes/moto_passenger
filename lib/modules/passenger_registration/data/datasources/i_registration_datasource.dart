abstract class IRegistrationDatasource {
  Future<List<Map<String, dynamic>>> getPublicPartitions();

  Future<Map<String, dynamic>> selfRegister(Map<String, dynamic> data);
}
