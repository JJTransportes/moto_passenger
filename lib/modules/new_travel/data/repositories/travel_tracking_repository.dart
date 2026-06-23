import 'package:moto_passenger/modules/new_travel/data/datasources/travel_tracking_datasource.dart';
import 'package:moto_passenger/modules/new_travel/domain/entities/travel_tracking_entity.dart';

abstract class ITravelTrackingRepository {
  Future<TravelTrackingEntity> getTravel(String travelId);
  Future<void> cancelTravel(String travelId, {String? reason});
  Future<DriverInfoEntity> getDriverProfile(String driverId);
}

class TravelTrackingRepository implements ITravelTrackingRepository {
  final ITravelTrackingDatasource _datasource;

  TravelTrackingRepository(this._datasource);

  @override
  Future<TravelTrackingEntity> getTravel(String travelId) async {
    final data = await _datasource.getTravel(travelId);

    TravelStatus status;
    switch (data['status'] as String?) {
      case 'Pending':
        status = TravelStatus.pending;
        break;
      case 'Accepted':
        status = TravelStatus.accepted;
        break;
      case 'InProgress':
        status = TravelStatus.inProgress;
        break;
      case 'Completed':
        status = TravelStatus.completed;
        break;
      case 'Cancelled':
        status = TravelStatus.cancelled;
        break;
      default:
        status = TravelStatus.pending;
    }

    // Extract destination coordinates from first route
    final routes = data['routes'] as List?;
    double? destLat, destLng;
    if (routes != null && routes.isNotEmpty) {
      destLat = (routes[0]['destinationLatitude'] as num?)?.toDouble();
      destLng = (routes[0]['destinationLongitude'] as num?)?.toDouble();
    }

    return TravelTrackingEntity(
      travelId: data['travelId'] as String,
      orderId: data['orderId'] as String,
      status: status,
      createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      startedAt: DateTime.tryParse(data['startedAt']?.toString() ?? ''),
      finishedAt: DateTime.tryParse(data['finishedAt']?.toString() ?? ''),
      cancelledAt: DateTime.tryParse(data['cancelledAt']?.toString() ?? ''),
      cancellationReason: data['cancellationReason'] as String?,
      destinationLatitude: destLat,
      destinationLongitude: destLng,
    );
  }

  @override
  Future<void> cancelTravel(String travelId, {String? reason}) async {
    await _datasource.cancelTravel(travelId, reason: reason);
  }

  @override
  Future<DriverInfoEntity> getDriverProfile(String driverId) async {
    final data = await _datasource.getDriverProfile(driverId);
    return DriverInfoEntity(
      driverId: data['driverId'] as String,
      fullName: data['fullName'] as String? ?? 'Motorista',
      vehicleModel: data['vehicle']?['model'] as String?,
      vehiclePlate: data['vehicle']?['plate'] as String?,
      vehicleColor: data['vehicle']?['color'] as String?,
    );
  }
}
