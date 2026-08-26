enum TravelStatus { pending, accepted, inProgress, completed, cancelled }

class TravelTrackingEntity {
  final String travelId;
  final String orderId;
  final TravelStatus status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final String? driverId;
  final DriverInfoEntity? driver;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final String? routePolyline;

  const TravelTrackingEntity({
    required this.travelId,
    required this.orderId,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.finishedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.driverId,
    this.driver,
    this.destinationLatitude,
    this.destinationLongitude,
    this.routePolyline,
  });
}

class DriverInfoEntity {
  final String driverId;
  final String fullName;
  final String? photoUrl;
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? vehiclePlate;
  final int? travelCount;

  const DriverInfoEntity({
    required this.driverId,
    required this.fullName,
    this.photoUrl,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehiclePlate,
    this.travelCount,
  });
}
