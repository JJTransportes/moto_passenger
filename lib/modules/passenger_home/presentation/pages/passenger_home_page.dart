import 'dart:async';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_passenger/core/auth/auth_storage.dart';
import 'package:moto_passenger/core/location/location_service.dart';
import 'package:moto_passenger/core/navigation/route_observer.dart';
import 'package:moto_passenger/core/notifications/home_entry.dart';
import 'package:moto_passenger/core/notifications/pending_notification_router.dart';
import 'package:moto_passenger/modules/passenger_home/presentation/blocs/passenger_home_bloc.dart';
import 'package:moto_passenger/modules/passenger_home/presentation/blocs/passenger_home_event.dart';
import 'package:moto_passenger/modules/passenger_home/presentation/blocs/passenger_home_state.dart';
import 'package:moto_passenger/modules/passenger_home/presentation/mixins/passenger_home_mixin.dart';

class PassengerHomePage extends StatefulWidget {
  const PassengerHomePage({super.key});

  @override
  State<PassengerHomePage> createState() => _PassengerHomePageState();
}

class _PassengerHomePageState extends State<PassengerHomePage>
    with PassengerHomeMixin, RouteAware, WidgetsBindingObserver {
  Timer? _passengerPositionTimer;
  bool _isAppActive = true;
  bool _positionUpdateInFlight = false;

  static const _positionInterval = Duration(seconds: 10);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      floatingActionButton: BlocBuilder<PassengerHomeBloc, PassengerHomeState>(
        builder: (context, state) => homeFab(
          hasActiveTravel:
              state is PassengerHomeLoaded && state.currentTravel != null,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    BlocProvider.of<PassengerHomeBloc>(context).add(const LoadPassengerHome());
    _startPositionReporting(sendImmediately: true);

    // Push (spec passenger-push-notifications): a tela inicial é onde a sessão fica
    // pronta; abre o toque guardado enquanto ela não estava (cold start ou login
    // depois de sessão expirada). Depois do primeiro quadro, para poder navegar.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => onHomeEntered(() => Modular.get<PendingNotificationRouter>()),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    appRouteObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    appRouteObserver.unsubscribe(this);
    _passengerPositionTimer?.cancel();

    super.dispose();
  }

  @override
  void didPopNext() {
    // Voltou pra Home depois de uma tela por cima ser fechada (nova
    // viagem cancelada/criada, rastreamento, etc.) — refaz o fetch sempre,
    // sem depender de pull-to-refresh manual ou de cada chamador lembrar de
    // disparar um refresh.
    BlocProvider.of<PassengerHomeBloc>(
      context,
    ).add(const RefreshPassengerHome());
    _startPositionReporting(sendImmediately: true);
  }

  @override
  void didPushNext() {
    // Keep reporting while another app page is above Home (for example while
    // requesting or tracking a trip). Reporting stops when the app itself is
    // backgrounded or this state is disposed.
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppActive = state == AppLifecycleState.resumed;
    if (_isAppActive) {
      _startPositionReporting(sendImmediately: true);
    } else {
      _passengerPositionTimer?.cancel();
    }
  }

  void _startPositionReporting({bool sendImmediately = false}) {
    _passengerPositionTimer?.cancel();
    if (!_isAppActive) return;

    if (sendImmediately) {
      _updatePassengerPosition();
    }
    _passengerPositionTimer = Timer.periodic(
      _positionInterval,
      (_) => _updatePassengerPosition(),
    );
  }

  Future<void> _updatePassengerPosition() async {
    if (_positionUpdateInFlight) return;
    _positionUpdateInFlight = true;
    try {
      final dio = Modular.get<Dio>();
      final authStorage = Modular.get<AuthStorage>();
      final localtionService = Modular.get<LocationService>();
      final position = await localtionService.getCurrentPosition();
      final userId = await authStorage.getUserId();

      if (!mounted || !_isAppActive) return;
      final current = position.position;
      if (!position.isGranted || current == null || userId == null) return;

      final response = await dio.post(
        '/api/positions/passengers/$userId',
        data: {
          "latitude": current.latitude,
          "longitude": current.longitude,
        },
      );

      log('${response.statusCode}');
    } on DioException catch (e) {
      log(e.message ?? "");
      return;
    } finally {
      _positionUpdateInFlight = false;
    }
  }
}
