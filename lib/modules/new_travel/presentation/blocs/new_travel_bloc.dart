import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:moto_passenger/core/location/location_service.dart';
import 'package:moto_passenger/core/maps/i_places_autocomplete_service.dart';
import 'package:moto_passenger/modules/new_travel/data/repositories/new_travel_repository.dart';
import 'package:moto_passenger/modules/new_travel/domain/entities/travel_route_entity.dart';
import 'package:moto_passenger/modules/new_travel/presentation/blocs/new_travel_event.dart';
import 'package:moto_passenger/modules/new_travel/presentation/blocs/new_travel_state.dart';

class NewTravelBloc extends Bloc<NewTravelEvent, NewTravelState> {
  final NewTravelRepository _repository;
  final LocationService _locationService;
  final IPlacesAutocompleteService _placesService;

  NewTravelBloc(
    this._repository,
    this._locationService,
    this._placesService,
  ) : super(const NewTravelInitial()) {
    on<GetCurrentLocation>(_onGetCurrentLocation);
    on<SearchPlaces>(_onSearchPlaces);
    on<SelectPlace>(_onSelectPlace);
    on<CalculateRoute>(_onCalculateRoute);
    on<ConfirmTravel>(_onConfirm);
  }

  String _locationErrorMessage(LocationStatus status) {
    switch (status) {
      case LocationStatus.serviceDisabled:
        return 'Serviço de localização desativado.';
      case LocationStatus.denied:
        return 'Permissão de localização negada.';
      case LocationStatus.deniedForever:
        return 'Permissão de localização negada permanentemente. Ative nas configurações do app.';
      case LocationStatus.granted:
        return 'Erro ao obter localização.';
    }
  }

  Future<void> _onCalculateRoute(
    CalculateRoute event,
    Emitter<NewTravelState> emit,
  ) async {
    final currentState = state;
    double originLat;
    double originLng;

    if (currentState is NewTravelLocationLoaded) {
      originLat = currentState.position.latitude;
      originLng = currentState.position.longitude;
    } else {
      emit(const NewTravelFailure(message: 'Localização não disponível'));
      return;
    }

    emit(const NewTravelRouteCalculating());

    try {
      final result = await _placesService.getRouteDetails(
        originLat: originLat,
        originLng: originLng,
        destLat: event.latitude,
        destLng: event.longitude,
      );

      emit(
        NewTravelRouteReady(
          route: TravelRouteEntity(
            originLat: result.originLat,
            originLng: result.originLng,
            destinationLat: result.destLat,
            destinationLng: result.destLng,
            departureAddress: result.departureAddress,
            destinationAddress: result.destinationAddress,
            distanceMeters: result.distanceMeters,
            timeMinutes: result.timeHours * 60 + result.timeMinutes,
            encodedPolyline: result.encodedPolyline,
          ),
        ),
      );
    } catch (e) {
      emit(NewTravelFailure(message: e.toString()));
    }
  }

  Future<void> _onConfirm(
    ConfirmTravel event,
    Emitter<NewTravelState> emit,
  ) async {
    emit(const NewTravelCreating());

    try {
      final request = {
        'destinationLatitude': event.destinationLat,
        'destinationLongitude': event.destinationLng,
        'passengerLatitude': event.originLat,
        'passengerLongitude': event.originLng,
      };

      final result = await _repository.createOrder(request);
      emit(
        NewTravelCreated(
          orderId: result['orderId'] as String,
        ),
      );
    } catch (e) {
      emit(NewTravelFailure(message: e.toString()));
    }
  }

  Future<void> _onGetCurrentLocation(
    GetCurrentLocation event,
    Emitter<NewTravelState> emit,
  ) async {
    emit(const NewTravelLocationLoading());

    try {
      final result = await _locationService.getCurrentPosition();

      if (!result.isGranted) {
        emit(
          NewTravelLocationError(
            message: _locationErrorMessage(result.status),
            status: result.status,
          ),
        );
        return;
      }

      final position = result.position!;
      emit(
        NewTravelLocationLoaded(
          position: LatLng(position.latitude, position.longitude),
        ),
      );
    } catch (e) {
      emit(
        NewTravelLocationError(
          message: e.toString(),
          status: LocationStatus.denied,
        ),
      );
    }
  }

  Future<void> _onSearchPlaces(
    SearchPlaces event,
    Emitter<NewTravelState> emit,
  ) async {
    if (event.query.length < 3) {
      emit(NewTravelPlacesLoaded(suggestions: [], query: event.query));
      return;
    }

    emit(const NewTravelPlacesLoading());

    try {
      final results = await _placesService.search(event.query);
      emit(NewTravelPlacesLoaded(suggestions: results, query: event.query));
    } catch (e) {
      emit(NewTravelFailure(message: e.toString()));
    }
  }

  Future<void> _onSelectPlace(
    SelectPlace event,
    Emitter<NewTravelState> emit,
  ) async {
    final originLat = event.suggestion.latitude;
    final originLng = event.suggestion.longitude;

    emit(const NewTravelRouteCalculating());

    try {
      final result = await _placesService.getRouteDetails(
        originLat: originLat,
        originLng: originLng,
        destLat: event.suggestion.latitude,
        destLng: event.suggestion.longitude,
      );

      emit(
        NewTravelRouteReady(
          route: TravelRouteEntity(
            originLat: result.originLat,
            originLng: result.originLng,
            destinationLat: result.destLat,
            destinationLng: result.destLng,
            departureAddress: result.departureAddress,
            destinationAddress: result.destinationAddress,
            distanceMeters: result.distanceMeters,
            timeMinutes: result.timeHours * 60 + result.timeMinutes,
            encodedPolyline: result.encodedPolyline,
          ),
        ),
      );
    } catch (e) {
      emit(NewTravelFailure(message: e.toString()));
    }
  }
}
