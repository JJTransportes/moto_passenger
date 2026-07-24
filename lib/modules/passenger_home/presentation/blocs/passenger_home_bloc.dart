import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moto_passenger/core/local_db/repositories/profile_local_repository.dart';
import 'package:moto_passenger/core/local_db/repositories/travel_local_repository.dart';
import 'package:moto_passenger/modules/passenger_home/domain/entities/passenger_profile_entity.dart';
import 'package:moto_passenger/modules/passenger_home/domain/entities/travel_summary_entity.dart';
import 'package:moto_passenger/modules/passenger_home/domain/usecases/i_get_passenger_profile_usecase.dart';
import 'package:moto_passenger/modules/passenger_home/domain/usecases/i_get_travels_usecase.dart';
import 'package:moto_passenger/modules/passenger_home/presentation/blocs/passenger_home_event.dart';
import 'package:moto_passenger/modules/passenger_home/presentation/blocs/passenger_home_state.dart';

class PassengerHomeBloc extends Bloc<PassengerHomeEvent, PassengerHomeState> {
  final IGetPassengerProfileUsecase _getProfile;
  final IGetActiveTravelUsecase _getActiveTravel;
  final IGetLastTravelsUsecase _getLastTravels;
  final ProfileLocalRepository _profileLocal;
  final TravelLocalRepository _travelLocal;

  PassengerHomeBloc({
    required IGetPassengerProfileUsecase getProfile,
    required IGetActiveTravelUsecase getActiveTravel,
    required IGetLastTravelsUsecase getLastTravels,
    required ProfileLocalRepository profileLocal,
    required TravelLocalRepository travelLocal,
  })  : _getProfile = getProfile,
        _getActiveTravel = getActiveTravel,
        _getLastTravels = getLastTravels,
        _profileLocal = profileLocal,
        _travelLocal = travelLocal,
        super(const PassengerHomeInitial()) {
    on<LoadPassengerHome>(_onLoad);
    on<RefreshPassengerHome>(_onRefresh);
  }

  Future<void> _onLoad(
      LoadPassengerHome event, Emitter<PassengerHomeState> emit) async {
    emit(const PassengerHomeLoading());

    // ── Step 1: Try local cache ────────────────────────────────
    final cachedActive = await _travelLocal.getActiveTravel();
    final cachedTravels = await _travelLocal.getCachedTravels();

    // ── Step 2: Fetch from remote API ──────────────────────────
    final profileResult = await _getProfile();

    if (profileResult.isError()) {
      // If cached data exists, show it even on failure
      if (cachedTravels.isNotEmpty || cachedActive != null) {
        emit(PassengerHomeLoaded(
          profile: const PassengerProfileEntity(
              id: '', fullName: '', email: ''),
          currentTravel: cachedActive?.toEntity(),
          lastTravels: cachedTravels.map((t) => t.toEntity()).toList(),
        ));
        return;
      }
      emit(PassengerHomeFailure(message: 'Erro ao carregar perfil'));
      return;
    }

    final profile = profileResult.getOrThrow();

    // Save profile to cache
    await _profileLocal.saveProfile(
      userId: profile.id,
      fullName: profile.fullName,
      email: profile.email,
      photoUrl: profile.photoUrl,
    );

    final activeResult = await _getActiveTravel();
    final lastTravelsResult = await _getLastTravels();

    final TravelSummaryEntity? activeTravel =
        activeResult.isSuccess() && activeResult.getOrThrow().isNotEmpty
            ? activeResult.getOrThrow().first
            : null;

    final lastTravels = lastTravelsResult.isSuccess()
        ? lastTravelsResult.getOrThrow()
        : <TravelSummaryEntity>[];

    // Save travels to cache
    await _travelLocal.saveActiveTravel(activeTravel);
    await _travelLocal.cacheTravels(lastTravels);

    emit(PassengerHomeLoaded(
      profile: profile,
      currentTravel: activeTravel,
      lastTravels: lastTravels,
    ));
  }

  Future<void> _onRefresh(
      RefreshPassengerHome event, Emitter<PassengerHomeState> emit) async {
    final oldState = state;
    if (oldState is! PassengerHomeLoaded) {
      emit(const PassengerHomeLoading());
      add(const LoadPassengerHome());
      return;
    }

    final profileResult = await _getProfile();
    if (profileResult.isError()) return;

    final profile = profileResult.getOrThrow();

    // Save profile to cache
    await _profileLocal.saveProfile(
      userId: profile.id,
      fullName: profile.fullName,
      email: profile.email,
      photoUrl: profile.photoUrl,
    );

    final activeResult = await _getActiveTravel();
    final lastTravelsResult = await _getLastTravels();

    final TravelSummaryEntity? activeTravel =
        activeResult.isSuccess() && activeResult.getOrThrow().isNotEmpty
            ? activeResult.getOrThrow().first
            : null;

    final lastTravels = lastTravelsResult.isSuccess()
        ? lastTravelsResult.getOrThrow()
        : oldState.lastTravels;

    // Save travels to cache
    await _travelLocal.saveActiveTravel(activeTravel);
    await _travelLocal.cacheTravels(lastTravels);

    emit(PassengerHomeLoaded(
      profile: profile,
      currentTravel: activeTravel,
      lastTravels: lastTravels,
    ));
  }
}
