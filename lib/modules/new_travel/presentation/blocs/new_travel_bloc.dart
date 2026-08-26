import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:moto_passenger/core/location/location_service.dart';
import 'package:moto_passenger/core/maps/i_places_autocomplete_service.dart';
import 'package:moto_passenger/modules/new_travel/data/datasources/new_travel_datasource.dart';
import 'package:moto_passenger/modules/new_travel/data/repositories/new_travel_repository.dart';
import 'package:moto_passenger/modules/new_travel/domain/entities/travel_route_entity.dart';
import 'package:moto_passenger/modules/new_travel/presentation/blocs/new_travel_event.dart';
import 'package:moto_passenger/modules/new_travel/presentation/blocs/new_travel_state.dart';
import 'package:moto_passenger/modules/new_travel/presentation/pages/new_travel_page.dart';

class NewTravelBloc extends Bloc<NewTravelEvent, NewTravelState> {
  final NewTravelRepository _repository;
  final LocationService _locationService;
  final IPlacesAutocompleteService _placesService;

  /// Persisted across state changes so route calculation always has an origin.
  LatLng? _currentPosition;

  NewTravelBloc(
    this._repository,
    this._locationService,
    this._placesService,
  ) : super(const NewTravelCheckingPending()) {
    on<CheckPendingOrder>(_onCheckPendingOrder);
    on<CancelPendingOrder>(_onCancelPendingOrder);
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
    final origin = _currentPosition;
    if (origin == null) {
      emit(const NewTravelFailure(message: 'Localização não disponível'));
      return;
    }

    emit(const NewTravelRouteCalculating());

    try {
      final result = await _placesService.getRouteDetails(
        originLat: origin.latitude,
        originLng: origin.longitude,
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

  Future<void> _onCheckPendingOrder(
    CheckPendingOrder event,
    Emitter<NewTravelState> emit,
  ) async {
    emit(const NewTravelCheckingPending());

    try {
      final order = await _repository.getLatestOrder();

      if (order == null) {
        // No pending order — proceed to normal flow
        add(const GetCurrentLocation());
        return;
      }

      final status = order['status'] as String?;

      if (status == 'Pending') {
        emit(
          NewTravelPendingOrder(
            orderId: order['orderId'] as String,
            travelId: order['travelId'] as String? ?? '',
            createdAt: DateTime.tryParse(order['createdAt']?.toString() ?? '') ?? DateTime.now(),
            destinationAddress: order['destinationAddress'] as String?,
          ),
        );
      } else if (status == 'Accepted' || status == 'InProgress') {
        final travelId = order['travelId'] as String?;
        if (travelId != null) {
          emit(
            NewTravelActiveOrder(
              travelId: travelId,
              status: status!,
            ),
          );
        } else {
          add(const GetCurrentLocation());
        }
      } else {
        // Completed, Cancelled — proceed normally
        add(const GetCurrentLocation());
      }
    } catch (_) {
      // Network error — proceed anyway
      add(const GetCurrentLocation());
    }
  }

  Future<void> _onCancelPendingOrder(
    CancelPendingOrder event,
    Emitter<NewTravelState> emit,
  ) async {
    try {
      await _repository.cancelOrder(event.orderId);
    } catch (_) {
      // Even if cancel fails, let the user proceed
    }
    add(const GetCurrentLocation());
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

      final result = event.orderType == OrderType.normal
          ? await _repository.createOrder(request) //
          : await _repository.createPriorityOrder(request);

      emit(
        NewTravelCreated(
          orderId: result['orderId'] as String,
        ),
      );
    } on NoDriversAvailableException catch (e) {
      emit(
        NewTravelNoDriversAvailable(
          partitionAcronym: e.partitionAcronym,
          message: e.message,
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
      _currentPosition = LatLng(position.latitude, position.longitude);
      emit(
        NewTravelLocationLoaded(
          position: _currentPosition!,
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
    final origin = _currentPosition;
    if (origin == null) {
      emit(const NewTravelFailure(message: 'Localização não disponível'));
      return;
    }

    emit(const NewTravelRouteCalculating());

    try {
      final result = await _placesService.getRouteDetails(
        originLat: origin.latitude,
        originLng: origin.longitude,
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
