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
  final DriverInfoEntity? driver;
  final double? destinationLatitude;
  final double? destinationLongitude;

  const TravelTrackingEntity({
    required this.travelId,
    required this.orderId,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.finishedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.driver,
    this.destinationLatitude,
    this.destinationLongitude,
  });
}

class DriverInfoEntity {
  final String driverId;
  final String fullName;
  final String? vehicleModel;
  final String? vehiclePlate;
  final String? vehicleColor;

  const DriverInfoEntity({
    required this.driverId,
    required this.fullName,
    this.vehicleModel,
    this.vehiclePlate,
    this.vehicleColor,
  });
}
