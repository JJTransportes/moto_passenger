import 'dart:async';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_passenger/core/auth/auth_storage.dart';
import 'package:moto_passenger/core/location/location_service.dart';
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
  Timer? _passengerPositionTimer;

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

    _passengerPositionTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _updatePassengerPosition(),
    );
  }

  @override
  void dispose() {
    _passengerPositionTimer?.cancel();

    super.dispose();
  }

  Future<void> _updatePassengerPosition() async {
    try {
      final dio = Modular.get<Dio>();
      final authStorage = Modular.get<AuthStorage>();
      final localtionService = Modular.get<LocationService>();
      final position = await localtionService.getCurrentPosition();
      final userId = await authStorage.getUserId();

      final response = await dio.post(
        '/api/positions/passengers/$userId',
        data: {
          "latitude": position.position?.latitude,
          "longitude": position.position?.longitude,
        },
      );

      log('${response.statusCode}');
    } on DioException catch (e) {
      log(e.message ?? "");
      return;
    }
  }
}
