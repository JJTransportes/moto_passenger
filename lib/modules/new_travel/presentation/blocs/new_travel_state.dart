import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:moto_passenger/core/location/location_service.dart';
import 'package:moto_passenger/core/maps/places_autocomplete_service.dart';
import 'package:moto_passenger/modules/new_travel/domain/entities/travel_route_entity.dart';

sealed class NewTravelState {
  const NewTravelState();
}

class NewTravelInitial extends NewTravelState {
  const NewTravelInitial();
}

class NewTravelLocationLoading extends NewTravelState {
  const NewTravelLocationLoading();
}

class NewTravelLocationLoaded extends NewTravelState {
  final LatLng position;

  const NewTravelLocationLoaded({required this.position});
}

class NewTravelLocationError extends NewTravelState {
  final String message;
  final LocationStatus status;

  const NewTravelLocationError({
    required this.message,
    required this.status,
  });
}

class NewTravelPlacesLoading extends NewTravelState {
  const NewTravelPlacesLoading();
}

class NewTravelPlacesLoaded extends NewTravelState {
  final List<PlaceSuggestion> suggestions;
  final String query;

  const NewTravelPlacesLoaded({
    required this.suggestions,
    required this.query,
  });
}

class NewTravelRouteCalculating extends NewTravelState {
  const NewTravelRouteCalculating();
}

class NewTravelRouteReady extends NewTravelState {
  final TravelRouteEntity route;

  const NewTravelRouteReady({required this.route});
}

class NewTravelCreating extends NewTravelState {
  const NewTravelCreating();
}

class NewTravelCreated extends NewTravelState {
  final String orderId;

  const NewTravelCreated({
    required this.orderId,
  });
}

class NewTravelNoDriversAvailable extends NewTravelState {
  final String partitionAcronym;
  final String message;

  const NewTravelNoDriversAvailable({
    required this.partitionAcronym,
    required this.message,
  });
}

class NewTravelFailure extends NewTravelState {
  final String message;

  const NewTravelFailure({required this.message});
}

class NewTravelCheckingPending extends NewTravelState {
  const NewTravelCheckingPending();
}

class NewTravelPendingOrder extends NewTravelState {
  final String orderId;
  final String travelId;
  final DateTime createdAt;
  final String? destinationAddress;

  const NewTravelPendingOrder({
    required this.orderId,
    required this.travelId,
    required this.createdAt,
    this.destinationAddress,
  });
}

class NewTravelActiveOrder extends NewTravelState {
  final String travelId;
  final String status;

  const NewTravelActiveOrder({
    required this.travelId,
    required this.status,
  });
}
