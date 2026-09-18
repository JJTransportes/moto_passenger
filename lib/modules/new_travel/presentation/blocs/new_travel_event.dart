import 'package:moto_passenger/core/maps/places_autocomplete_service.dart';
import 'package:moto_passenger/modules/new_travel/presentation/pages/new_travel_page.dart';

sealed class NewTravelEvent {
  const NewTravelEvent();
}

class GetCurrentLocation extends NewTravelEvent {
  const GetCurrentLocation();
}

class SearchPlaces extends NewTravelEvent {
  final String query;

  const SearchPlaces({required this.query});
}

class SelectPlace extends NewTravelEvent {
  final PlaceSuggestion suggestion;

  const SelectPlace({required this.suggestion});
}

class CalculateRoute extends NewTravelEvent {
  final double latitude;
  final double longitude;

  const CalculateRoute({
    required this.latitude,
    required this.longitude,
  });
}

class ConfirmTravel extends NewTravelEvent {
  final double originLat;
  final double originLng;
  final double destinationLat;
  final double destinationLng;
  final OrderType orderType;

  const ConfirmTravel({
    required this.originLat,
    required this.originLng,
    required this.destinationLat,
    required this.destinationLng,
    required this.orderType,
  });
}

class CheckPendingOrder extends NewTravelEvent {
  const CheckPendingOrder();
}

class CancelPendingOrder extends NewTravelEvent {
  final String orderId;

  const CancelPendingOrder({required this.orderId});
}
