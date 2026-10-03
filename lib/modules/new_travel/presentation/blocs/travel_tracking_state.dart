import 'package:moto_passenger/modules/new_travel/domain/entities/travel_tracking_entity.dart';

sealed class TravelTrackingState {
  const TravelTrackingState();
}

class TravelTrackingInitial extends TravelTrackingState {
  const TravelTrackingInitial();
}

class TravelTrackingLoading extends TravelTrackingState {
  const TravelTrackingLoading();
}

class TravelTrackingPending extends TravelTrackingState {
  final String travelId;
  final String orderId;

  const TravelTrackingPending({
    required this.travelId,
    required this.orderId,
  });
}

class TravelTrackingAccepted extends TravelTrackingState {
  final String travelId;
  final DriverInfoEntity? driver;
  final double? driverLatitude;
  final double? driverLongitude;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final int? distanceToDestinationMeters;
  final int? remainingTimeMinutes;
  final String? routePolyline;
  final DateTime? requestedAt;
  final PickupProximity pickupProximity;

  const TravelTrackingAccepted({
    required this.travelId,
    this.driver,
    this.driverLatitude,
    this.driverLongitude,
    this.destinationLatitude,
    this.destinationLongitude,
    this.distanceToDestinationMeters,
    this.remainingTimeMinutes,
    this.routePolyline,
    this.requestedAt,
    this.pickupProximity = PickupProximity.none,
  });

  TravelTrackingAccepted copyWith({PickupProximity? pickupProximity}) => TravelTrackingAccepted(
        travelId: travelId,
        driver: driver,
        driverLatitude: driverLatitude,
        driverLongitude: driverLongitude,
        destinationLatitude: destinationLatitude,
        destinationLongitude: destinationLongitude,
        distanceToDestinationMeters: distanceToDestinationMeters,
        remainingTimeMinutes: remainingTimeMinutes,
        routePolyline: routePolyline,
        requestedAt: requestedAt,
        pickupProximity: pickupProximity ?? this.pickupProximity,
      );
}

class TravelTrackingInProgress extends TravelTrackingState {
  final String travelId;
  final DriverInfoEntity? driver;
  final double? driverLatitude;
  final double? driverLongitude;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final int? distanceToDestinationMeters;
  final int? remainingTimeMinutes;
  final String? routePolyline;
  final DateTime? requestedAt;

  const TravelTrackingInProgress({
    required this.travelId,
    this.driver,
    this.driverLatitude,
    this.driverLongitude,
    this.destinationLatitude,
    this.destinationLongitude,
    this.distanceToDestinationMeters,
    this.remainingTimeMinutes,
    this.routePolyline,
    this.requestedAt,
  });
}

class TravelTrackingCompleted extends TravelTrackingState {
  final String travelId;

  const TravelTrackingCompleted({required this.travelId});
}

class TravelTrackingCancelled extends TravelTrackingState {
  final String travelId;
  final String? reason;

  const TravelTrackingCancelled({
    required this.travelId,
    this.reason,
  });
}

class TravelTrackingFailure extends TravelTrackingState {
  final String message;

  const TravelTrackingFailure({required this.message});
}
