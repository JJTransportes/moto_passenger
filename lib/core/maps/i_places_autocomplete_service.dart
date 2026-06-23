import 'package:moto_passenger/core/maps/places_autocomplete_service.dart';

abstract class IPlacesAutocompleteService {
  Future<PlaceDetail> getPlaceDetails(String placeId);
  Future<List<PlaceSuggestion>> search(String query);
  Future<RouteDetailResult> getRouteDetails({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  });
}
