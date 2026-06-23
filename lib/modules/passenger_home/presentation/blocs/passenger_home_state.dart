import 'package:moto_passenger/modules/passenger_home/domain/entities/passenger_profile_entity.dart';
import 'package:moto_passenger/modules/passenger_home/domain/entities/travel_summary_entity.dart';

sealed class PassengerHomeState {
  const PassengerHomeState();
}

class PassengerHomeInitial extends PassengerHomeState {
  const PassengerHomeInitial();
}

class PassengerHomeLoading extends PassengerHomeState {
  const PassengerHomeLoading();
}

class PassengerHomeLoaded extends PassengerHomeState {
  final PassengerProfileEntity profile;
  final TravelSummaryEntity? currentTravel;
  final List<TravelSummaryEntity> lastTravels;

  const PassengerHomeLoaded({
    required this.profile,
    this.currentTravel,
    required this.lastTravels,
  });
}

class PassengerHomeFailure extends PassengerHomeState {
  final String message;

  const PassengerHomeFailure({required this.message});
}
