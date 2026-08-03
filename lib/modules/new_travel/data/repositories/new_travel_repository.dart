import 'package:moto_passenger/modules/new_travel/data/datasources/new_travel_datasource.dart';

class NewTravelRepository {
  final INewTravelDatasource _datasource;

  NewTravelRepository(this._datasource);

  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> request) async {
    return await _datasource.createOrder(request);
  }

  Future<Map<String, dynamic>?> getLatestOrder() async {
    return await _datasource.getLatestOrder();
  }

  Future<void> cancelOrder(String orderId) async {
    await _datasource.cancelOrder(orderId);
  }
}
