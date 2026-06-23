import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moto_passenger/core/theme/app_theme.dart';
import 'package:moto_passenger/modules/passenger_home/presentation/blocs/passenger_home_bloc.dart';
import 'package:moto_passenger/modules/passenger_home/presentation/blocs/passenger_home_event.dart';
import 'package:moto_passenger/modules/passenger_home/presentation/blocs/passenger_home_state.dart';
import 'package:moto_passenger/modules/passenger_home/presentation/mixins/passenger_home_mixin.dart';

class PassengerHomePage extends StatefulWidget {
  const PassengerHomePage({super.key});

  @override
  State<PassengerHomePage> createState() => _PassengerHomePageState();
}

class _PassengerHomePageState extends State<PassengerHomePage> with PassengerHomeMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: BlocBuilder<PassengerHomeBloc, PassengerHomeState>(
          builder: (context, state) => switch (state) {
            PassengerHomeInitial() => defaultState(),
            PassengerHomeFailure(:final message) => failureState(message),
            PassengerHomeLoading() => loadingState(),
            PassengerHomeLoaded(
              :final profile,
              :final currentTravel,
              :final lastTravels,
            ) =>
              loadedState(
                profile,
                currentTravel,
                lastTravels,
              ),
          },
        ),
      ),
      floatingActionButton: homeFab(),
    );
  }

  @override
  void initState() {
    super.initState();
    BlocProvider.of<PassengerHomeBloc>(context).add(const LoadPassengerHome());
  }
}
