import 'package:moto_passenger/modules/passenger_home/data/models/passenger_profile_model.dart';
import 'package:moto_passenger/modules/passenger_home/data/models/travel_summary_model.dart';

abstract class IPassengerHomeDatasource {
  Future<PassengerProfileModel> getProfile();
  Future<PaginatedTravelListModel> getPassengerTravels({
    required List<String> status,
    int page = 1,
    int pageSize = 5,
  });
  Future<Map<String, dynamic>?> getActiveTravel();
}
