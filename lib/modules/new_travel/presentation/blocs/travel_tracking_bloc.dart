import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moto_passenger/modules/new_travel/data/repositories/travel_tracking_repository.dart';
import 'package:moto_passenger/modules/new_travel/domain/entities/travel_tracking_entity.dart';
import 'package:moto_passenger/modules/new_travel/presentation/blocs/travel_tracking_event.dart';
import 'package:moto_passenger/modules/new_travel/presentation/blocs/travel_tracking_state.dart';

class TravelTrackingBloc extends Bloc<TravelTrackingEvent, TravelTrackingState> {
  final ITravelTrackingRepository _repository;

  Timer? _pollTimer;
  int _pollFailCount = 0;

  static const int _pollIntervalNormal = 10;
  static const int _pollIntervalBackoff = 30;
  static const int _maxFailuresBeforeBackoff = 3;

  TravelTrackingBloc(this._repository) : super(const TravelTrackingInitial()) {
    on<LoadTravel>(_onLoadTravel);
    on<CancelTravel>(_onCancelTravel);
    on<TravelOrderAccepted>(_onOrderAccepted);
    on<TravelStarted>(_onTravelStarted);
    on<TravelCompleted>(_onTravelCompleted);
    on<TravelCancelled>(_onTravelCancelled);
    on<PollTravelStatus>(_onPollTravelStatus);
    on<DriverLocationUpdated>(_onDriverLocationUpdated);
    on<DistanceUpdated>(_onDistanceUpdated);
  }

  @override
  Future<void> close() {
    _stopPolling();
    return super.close();
  }

  // ─── Polling ───────────────────────────────────────────────────────────

  void _startPolling(String travelId) {
    _stopPolling();
    _pollTimer = Timer.periodic(
      const Duration(seconds: _pollIntervalNormal),
      (_) => add(PollTravelStatus(travelId)),
    );
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollFailCount = 0;
  }

  Future<void> _onPollTravelStatus(PollTravelStatus event, Emitter<TravelTrackingState> emit) async {
    try {
      final travel = await _repository.getTravel(event.travelId);
      _pollFailCount = 0;
      _updateStateFromTravel(travel, emit);

      // Stop polling when terminal status is reached
      if (travel.status == TravelStatus.completed ||
          travel.status == TravelStatus.cancelled) {
        _stopPolling();
      }
    } catch (_) {
      _pollFailCount++;
      if (_pollFailCount >= _maxFailuresBeforeBackoff) {
        _pollTimer?.cancel();
        _pollTimer = Timer.periodic(
          const Duration(seconds: _pollIntervalBackoff),
          (_) => add(PollTravelStatus(event.travelId)),
        );
      }
    }
  }

  /// Updates the state based on travel data from polling, but never regresses
  /// to an earlier status (e.g., if already Accepted, polling Pending is ignored).
  void _updateStateFromTravel(TravelTrackingEntity travel, Emitter<TravelTrackingState> emit) {
    final currentState = state;

    // Never regress from terminal states
    if (currentState is TravelTrackingCompleted || currentState is TravelTrackingCancelled) return;

    // Never go backwards in the lifecycle
    if (currentState is TravelTrackingAccepted && travel.status == TravelStatus.pending) return;
    if (currentState is TravelTrackingInProgress && travel.status == TravelStatus.accepted) return;
    if (currentState is TravelTrackingInProgress && travel.status == TravelStatus.pending) return;

    switch (travel.status) {
      case TravelStatus.pending:
        if (currentState is! TravelTrackingPending) {
          emit(TravelTrackingPending(travelId: travel.travelId, orderId: travel.orderId));
        }
      case TravelStatus.accepted:
        if (currentState is TravelTrackingAccepted && (currentState).driver != null) return;
        _emitAcceptedState(travel, emit);
      case TravelStatus.inProgress:
        if (currentState is! TravelTrackingInProgress) {
          emit(TravelTrackingInProgress(
            travelId: travel.travelId,
            driverLatitude: currentState is TravelTrackingAccepted ? currentState.driverLatitude : null,
            driverLongitude: currentState is TravelTrackingAccepted ? currentState.driverLongitude : null,
            destinationLatitude: travel.destinationLatitude,
            destinationLongitude: travel.destinationLongitude,
          ));
        }
      case TravelStatus.completed:
        emit(TravelTrackingCompleted(travelId: travel.travelId));
      case TravelStatus.cancelled:
        emit(TravelTrackingCancelled(travelId: travel.travelId, reason: travel.cancellationReason));
    }
  }

  Future<void> _emitAcceptedState(TravelTrackingEntity travel, Emitter<TravelTrackingState> emit) async {
    emit(TravelTrackingAccepted(
      travelId: travel.travelId,
      driver: null,
      destinationLatitude: travel.destinationLatitude,
      destinationLongitude: travel.destinationLongitude,
    ));
  }

  // ─── Event Handlers ────────────────────────────────────────────────────

  Future<void> _onCancelTravel(CancelTravel event, Emitter<TravelTrackingState> emit) async {
    try {
      await _repository.cancelTravel(event.travelId);
      _stopPolling();
      emit(TravelTrackingCancelled(travelId: event.travelId, reason: 'Cancelada pelo passageiro'));
    } catch (e) {
      emit(TravelTrackingFailure(message: e.toString()));
    }
  }

  Future<void> _onLoadTravel(LoadTravel event, Emitter<TravelTrackingState> emit) async {
    emit(const TravelTrackingLoading());

    try {
      final travel = await _repository.getTravel(event.travelId);

      switch (travel.status) {
        case TravelStatus.pending:
          emit(TravelTrackingPending(travelId: travel.travelId, orderId: travel.orderId));
        case TravelStatus.accepted:
          emit(TravelTrackingAccepted(
            travelId: travel.travelId,
            driver: travel.driver,
            destinationLatitude: travel.destinationLatitude,
            destinationLongitude: travel.destinationLongitude,
          ));
        case TravelStatus.inProgress:
          emit(TravelTrackingInProgress(
            travelId: travel.travelId,
            destinationLatitude: travel.destinationLatitude,
            destinationLongitude: travel.destinationLongitude,
          ));
        case TravelStatus.completed:
          emit(TravelTrackingCompleted(travelId: travel.travelId));
        case TravelStatus.cancelled:
          emit(TravelTrackingCancelled(travelId: travel.travelId, reason: travel.cancellationReason));
      }

      // Start polling for non-terminal statuses
      if (travel.status != TravelStatus.completed &&
          travel.status != TravelStatus.cancelled) {
        _startPolling(event.travelId);
      }
    } catch (e) {
      emit(TravelTrackingFailure(message: e.toString()));
    }
  }

  Future<void> _onOrderAccepted(TravelOrderAccepted event, Emitter<TravelTrackingState> emit) async {
    final currentState = state;
    // Preserve destination coordinates from current state if available
    final destLat = currentState is TravelTrackingPending ? null
        : (currentState is TravelTrackingAccepted ? currentState.destinationLatitude : null);
    final destLng = currentState is TravelTrackingPending ? null
        : (currentState is TravelTrackingAccepted ? currentState.destinationLongitude : null);

    try {
      final driverId = event.data['driverId'] as String?;
      if (driverId != null) {
        final driver = await _repository.getDriverProfile(driverId);
        emit(TravelTrackingAccepted(
          travelId: event.data['travelId'] as String,
          driver: driver,
          destinationLatitude: destLat,
          destinationLongitude: destLng,
        ));
      }
    } catch (e) {
      emit(TravelTrackingAccepted(
        travelId: event.data['travelId'] as String,
        driver: null,
        destinationLatitude: destLat,
        destinationLongitude: destLng,
      ));
    }
  }

  Future<void> _onTravelCancelled(TravelCancelled event, Emitter<TravelTrackingState> emit) async {
    _stopPolling();
    emit(TravelTrackingCancelled(travelId: event.data['travelId'] as String, reason: event.data['reason'] as String?));
  }

  Future<void> _onTravelCompleted(TravelCompleted event, Emitter<TravelTrackingState> emit) async {
    _stopPolling();
    emit(TravelTrackingCompleted(travelId: event.data['travelId'] as String));
  }

  Future<void> _onDriverLocationUpdated(
    DriverLocationUpdated event,
    Emitter<TravelTrackingState> emit,
  ) async {
    final currentState = state;
    final lat = (event.data['latitude'] as num?)?.toDouble();
    final lng = (event.data['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return;

    switch (currentState) {
      case TravelTrackingAccepted(:final travelId, :final driver,
            :final destinationLatitude, :final destinationLongitude,
            :final distanceToDestinationMeters, :final remainingTimeMinutes):
        emit(TravelTrackingAccepted(
          travelId: travelId, driver: driver,
          driverLatitude: lat, driverLongitude: lng,
          destinationLatitude: destinationLatitude, destinationLongitude: destinationLongitude,
          distanceToDestinationMeters: distanceToDestinationMeters, remainingTimeMinutes: remainingTimeMinutes,
        ));
      case TravelTrackingInProgress(:final travelId,
            :final destinationLatitude, :final destinationLongitude,
            :final distanceToDestinationMeters, :final remainingTimeMinutes):
        emit(TravelTrackingInProgress(
          travelId: travelId,
          driverLatitude: lat, driverLongitude: lng,
          destinationLatitude: destinationLatitude, destinationLongitude: destinationLongitude,
          distanceToDestinationMeters: distanceToDestinationMeters, remainingTimeMinutes: remainingTimeMinutes,
        ));
      default:
        break;
    }
  }

  Future<void> _onDistanceUpdated(
    DistanceUpdated event,
    Emitter<TravelTrackingState> emit,
  ) async {
    final currentState = state;
    final dist = event.data['distanceToDestinationInMeters'] as int?;
    final time = event.data['remainingTimeEstimate'] as int?;

    switch (currentState) {
      case TravelTrackingAccepted(:final travelId, :final driver,
            :final driverLatitude, :final driverLongitude,
            :final destinationLatitude, :final destinationLongitude):
        emit(TravelTrackingAccepted(
          travelId: travelId, driver: driver,
          driverLatitude: driverLatitude, driverLongitude: driverLongitude,
          destinationLatitude: destinationLatitude, destinationLongitude: destinationLongitude,
          distanceToDestinationMeters: dist, remainingTimeMinutes: time,
        ));
      case TravelTrackingInProgress(:final travelId,
            :final driverLatitude, :final driverLongitude,
            :final destinationLatitude, :final destinationLongitude):
        emit(TravelTrackingInProgress(
          travelId: travelId,
          driverLatitude: driverLatitude, driverLongitude: driverLongitude,
          destinationLatitude: destinationLatitude, destinationLongitude: destinationLongitude,
          distanceToDestinationMeters: dist, remainingTimeMinutes: time,
        ));
      default:
        break;
    }
  }

  Future<void> _onTravelStarted(TravelStarted event, Emitter<TravelTrackingState> emit) async {
    final currentState = state;
    final destLat = currentState is TravelTrackingAccepted ? currentState.destinationLatitude : null;
    final destLng = currentState is TravelTrackingAccepted ? currentState.destinationLongitude : null;
    final driverLat = currentState is TravelTrackingAccepted ? currentState.driverLatitude : null;
    final driverLng = currentState is TravelTrackingAccepted ? currentState.driverLongitude : null;

    emit(TravelTrackingInProgress(
      travelId: event.data['travelId'] as String,
      driverLatitude: driverLat,
      driverLongitude: driverLng,
      destinationLatitude: destLat,
      destinationLongitude: destLng,
    ));
  }
}
