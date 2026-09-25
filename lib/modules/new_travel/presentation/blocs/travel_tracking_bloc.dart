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
    print('[DIAG] bloc CREATED hash=$hashCode');
    on<LoadTravel>(_onLoadTravel);
    on<CancelTravel>(_onCancelTravel);
    on<TravelOrderAccepted>(_onOrderAccepted);
    on<TravelStarted>(_onTravelStarted);
    on<TravelCompleted>(_onTravelCompleted);
    on<TravelCancelled>(_onTravelCancelled);
    on<PollTravelStatus>(_onPollTravelStatus);
    on<DriverLocationUpdated>(_onDriverLocationUpdated);
    on<DistanceUpdated>(_onDistanceUpdated);
    on<PollingPaused>(_onPollingPaused);
  }

  @override
  Future<void> close() {
    _stopPolling();
    return super.close();
  }

  // ─── Driver profile resolution ──────────────────────────────────────────

  /// GET /api/travels/{id} já vem com nome/foto/veículo do motorista
  /// embutidos (backend) — não busca mais nada à parte via GET
  /// /api/drivers/{id}, que hoje exige papel GlobalAdmin (fechamos o IDOR
  /// que deixava qualquer autenticado ler o perfil completo de qualquer
  /// motorista) e sempre retornava 403 pra um passageiro. Puramente
  /// síncrono: prioriza o que veio na viagem mais recente, cai pro que já
  /// tinha se por algum motivo não vier (ex.: evento de SignalR sem dados
  /// completos, coberto no próximo poll/load).
  DriverInfoEntity? _resolveDriver(DriverInfoEntity? fromTravel, DriverInfoEntity? existing) {
    return fromTravel ?? existing;
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

  Future<void> _onPollingPaused(PollingPaused event, Emitter<TravelTrackingState> emit) async {
    _stopPolling();
  }

  Future<void> _onPollTravelStatus(PollTravelStatus event, Emitter<TravelTrackingState> emit) async {
    try {
      final travel = await _repository.getTravel(event.travelId);
      _pollFailCount = 0;
      await _updateStateFromTravel(travel, emit);

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
  Future<void> _updateStateFromTravel(TravelTrackingEntity travel, Emitter<TravelTrackingState> emit) async {
    final currentState = state;
    print('[DIAG] _updateStateFromTravel hash=$hashCode currentState=${currentState.runtimeType} travelStatus=${travel.status} isClosed=$isClosed');

    // Never regress from terminal states
    if (currentState is TravelTrackingCompleted || currentState is TravelTrackingCancelled) {
      print('[DIAG] guard: terminal state, ignoring');
      return;
    }

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
        final existingDriver = currentState is TravelTrackingAccepted ? currentState.driver : null;
        if (existingDriver != null && existingDriver.driverId == travel.driverId) return;
        await _emitAcceptedState(travel, emit);
      case TravelStatus.inProgress:
        final existingDriver = currentState is TravelTrackingInProgress
            ? currentState.driver
            : (currentState is TravelTrackingAccepted ? currentState.driver : null);
        final driver = _resolveDriver(travel.driver, existingDriver);
        if (currentState is! TravelTrackingInProgress || driver?.driverId != existingDriver?.driverId) {
          emit(TravelTrackingInProgress(
            travelId: travel.travelId,
            driver: driver,
            driverLatitude: currentState is TravelTrackingAccepted ? currentState.driverLatitude : null,
            driverLongitude: currentState is TravelTrackingAccepted ? currentState.driverLongitude : null,
            destinationLatitude: travel.destinationLatitude,
            destinationLongitude: travel.destinationLongitude,
            routePolyline: travel.routePolyline,
            requestedAt: travel.createdAt,
          ));
        }
      case TravelStatus.completed:
        emit(TravelTrackingCompleted(travelId: travel.travelId));
      case TravelStatus.cancelled:
        emit(TravelTrackingCancelled(travelId: travel.travelId, reason: travel.cancellationReason));
    }
  }

  Future<void> _emitAcceptedState(TravelTrackingEntity travel, Emitter<TravelTrackingState> emit) async {
    final driver = _resolveDriver(travel.driver, null);
    print('[DIAG] emitting Accepted hash=$hashCode travelId=${travel.travelId} isClosed=$isClosed');
    emit(TravelTrackingAccepted(
      travelId: travel.travelId,
      driver: driver,
      destinationLatitude: travel.destinationLatitude,
      destinationLongitude: travel.destinationLongitude,
      routePolyline: travel.routePolyline,
      requestedAt: travel.createdAt,
    ));
    print('[DIAG] emitted Accepted, bloc.state is now ${state.runtimeType}');
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

  /// `LoadTravel` pode ser disparado mais de uma vez para o mesmo travelId —
  /// cada recriação da página (ex.: usuário voltando e reentrando na tela
  /// via gesto do Android) dispara isso de novo no mesmo bloc. As respostas
  /// dessas chamadas HTTP concorrentes podem voltar fora de ordem, então
  /// delega pra `_updateStateFromTravel`, que já sabe ignorar dados
  /// desatualizados e nunca regredir de InProgress pra Accepted/Pending —
  /// sem isso, uma resposta atrasada de uma chamada anterior sobrescrevia o
  /// estado atual (e resetava a localização do motorista no mapa).
  Future<void> _onLoadTravel(LoadTravel event, Emitter<TravelTrackingState> emit) async {
    print('[DIAG] _onLoadTravel START hash=$hashCode travelId=${event.travelId} currentState=${state.runtimeType} isClosed=$isClosed');
    if (state is TravelTrackingInitial) {
      emit(const TravelTrackingLoading());
    }

    try {
      final travel = await _repository.getTravel(event.travelId);
      print('[DIAG] _onLoadTravel got travel status=${travel.status} hash=$hashCode isClosed=$isClosed');
      await _updateStateFromTravel(travel, emit);
      print('[DIAG] _onLoadTravel after _updateStateFromTravel, state=${state.runtimeType} hash=$hashCode');

      // Start polling for non-terminal statuses
      if (travel.status != TravelStatus.completed &&
          travel.status != TravelStatus.cancelled) {
        _startPolling(event.travelId);
      }
    } catch (e, st) {
      print('[DIAG] _onLoadTravel EXCEPTION: $e\n$st');
      if (state is TravelTrackingInitial || state is TravelTrackingLoading) {
        emit(TravelTrackingFailure(message: e.toString()));
      }
    }
  }

  Future<void> _onOrderAccepted(TravelOrderAccepted event, Emitter<TravelTrackingState> emit) async {
    final currentState = state;

    // "Pedido aceito" só é uma transição válida saindo de Pending (fluxo
    // normal: pedido pendente -> motorista aceita). O hub de SignalR pode
    // reenviar/duplicar esse evento ao reconectar (ex.: usuário reentrando
    // na tela várias vezes via swipe-back, o que reconecta o hub a cada
    // vez) — nesse caso o estado atual já não é mais Pending (é
    // Initial/Loading numa página recriada do zero, ou já Accepted/
    // InProgress), então o evento é redundante/atrasado e precisa ser
    // ignorado. Sem essa guarda, ele reemitia Accepted com
    // destinationLatitude/driverLatitude nulos (currentState não era
    // Accepted pra preservar essas coordenadas), jogando o mapa pro
    // fallback de São Paulo até o LoadTravel corrigir pra InProgress.
    if (currentState is! TravelTrackingPending) return;

    const destLat = null;
    const destLng = null;
    const routePolyline = null;
    const requestedAt = null;

    try {
      final driverId = event.data['driverId'] as String?;
      if (driverId != null) {
        // O payload do evento SignalR só traz o driverId, sem nome/foto/
        // veículo — não busca mais isso via GET /api/drivers/{id} (exige
        // GlobalAdmin, sempre 403 pra passageiro). Emite sem os detalhes
        // completos do motorista por enquanto; o próximo LoadTravel/poll
        // (GET /api/travels/{id}, já enriquecido) preenche isso.
        emit(TravelTrackingAccepted(
          travelId: event.data['travelId'] as String,
          driver: null,
          destinationLatitude: destLat,
          destinationLongitude: destLng,
          routePolyline: routePolyline,
          requestedAt: requestedAt,
        ));
      }
    } catch (e) {
      emit(TravelTrackingAccepted(
        travelId: event.data['travelId'] as String,
        driver: null,
        destinationLatitude: destLat,
        destinationLongitude: destLng,
        routePolyline: routePolyline,
        requestedAt: requestedAt,
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
            :final distanceToDestinationMeters, :final remainingTimeMinutes,
            :final routePolyline, :final requestedAt):
        emit(TravelTrackingAccepted(
          travelId: travelId, driver: driver,
          driverLatitude: lat, driverLongitude: lng,
          destinationLatitude: destinationLatitude, destinationLongitude: destinationLongitude,
          distanceToDestinationMeters: distanceToDestinationMeters, remainingTimeMinutes: remainingTimeMinutes,
          routePolyline: routePolyline, requestedAt: requestedAt,
        ));
      case TravelTrackingInProgress(:final travelId, :final driver,
            :final destinationLatitude, :final destinationLongitude,
            :final distanceToDestinationMeters, :final remainingTimeMinutes,
            :final routePolyline, :final requestedAt):
        emit(TravelTrackingInProgress(
          travelId: travelId, driver: driver,
          driverLatitude: lat, driverLongitude: lng,
          destinationLatitude: destinationLatitude, destinationLongitude: destinationLongitude,
          distanceToDestinationMeters: distanceToDestinationMeters, remainingTimeMinutes: remainingTimeMinutes,
          routePolyline: routePolyline, requestedAt: requestedAt,
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
            :final destinationLatitude, :final destinationLongitude,
            :final routePolyline, :final requestedAt):
        emit(TravelTrackingAccepted(
          travelId: travelId, driver: driver,
          driverLatitude: driverLatitude, driverLongitude: driverLongitude,
          destinationLatitude: destinationLatitude, destinationLongitude: destinationLongitude,
          distanceToDestinationMeters: dist, remainingTimeMinutes: time,
          routePolyline: routePolyline, requestedAt: requestedAt,
        ));
      case TravelTrackingInProgress(:final travelId, :final driver,
            :final driverLatitude, :final driverLongitude,
            :final destinationLatitude, :final destinationLongitude,
            :final routePolyline, :final requestedAt):
        emit(TravelTrackingInProgress(
          travelId: travelId, driver: driver,
          driverLatitude: driverLatitude, driverLongitude: driverLongitude,
          destinationLatitude: destinationLatitude, destinationLongitude: destinationLongitude,
          distanceToDestinationMeters: dist, remainingTimeMinutes: time,
          routePolyline: routePolyline, requestedAt: requestedAt,
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
    final driver = currentState is TravelTrackingAccepted ? currentState.driver : null;
    final routePolyline = currentState is TravelTrackingAccepted ? currentState.routePolyline : null;
    final requestedAt = currentState is TravelTrackingAccepted ? currentState.requestedAt : null;

    emit(TravelTrackingInProgress(
      travelId: event.data['travelId'] as String,
      driver: driver,
      driverLatitude: driverLat,
      driverLongitude: driverLng,
      destinationLatitude: destLat,
      destinationLongitude: destLng,
      routePolyline: routePolyline,
      requestedAt: requestedAt,
    ));
  }
}
