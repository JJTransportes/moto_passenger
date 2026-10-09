import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' hide ReadContext;
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:moto_passenger/core/auth/auth_storage.dart';
import 'package:moto_passenger/core/config/app_config.dart';
import 'package:moto_passenger/core/local_db/repositories/travel_local_repository.dart';
import 'package:moto_passenger/core/location/location_service.dart';
import 'package:moto_passenger/core/location/background_location_service.dart';
import 'package:moto_passenger/core/maps/polyline_decoder.dart';
import 'package:moto_passenger/core/network/signalr_service.dart';
import 'package:moto_passenger/modules/chat/presentation/session/chat_session.dart';
import 'package:moto_passenger/modules/chat/presentation/widgets/chat_action_button.dart';
import 'package:moto_passenger/design_system/design_system.dart';
import 'package:moto_passenger/modules/new_travel/domain/entities/travel_tracking_entity.dart';
import 'package:moto_passenger/modules/new_travel/presentation/blocs/travel_tracking_bloc.dart';
import 'package:moto_passenger/modules/new_travel/presentation/blocs/travel_tracking_event.dart';
import 'package:moto_passenger/modules/new_travel/presentation/blocs/travel_tracking_state.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class TravelTrackingPage extends StatefulWidget {
  final String travelId;
  final String? orderId;

  const TravelTrackingPage({
    super.key,
    required this.travelId,
    this.orderId,
  });

  @override
  State<TravelTrackingPage> createState() => _TravelTrackingPageState();
}

class _TravelTrackingPageState extends State<TravelTrackingPage>
    with WidgetsBindingObserver {
  StreamSubscription? _orderAcceptedSub;
  StreamSubscription? _travelStartedSub;
  StreamSubscription? _travelCompletedSub;
  StreamSubscription? _travelCancelledSub;
  StreamSubscription? _orderCancelledSub;
  StreamSubscription? _driverLocationSub;
  StreamSubscription? _distanceUpdateSub;
  StreamSubscription? _driverNearbySub;
  StreamSubscription? _driverArrivedSub;

  GoogleMapController? _mapController;
  bool _driverCameraEnabled = false;
  bool _travelPanelExpanded = true;
  double? _lastDriverLat;
  double? _lastDriverLng;
  double _lastDriverBearing = 0;
  String? _authToken;
  LatLng? _myLocation;
  BitmapDescriptor? _driverMarkerIcon;

  @override
  Widget build(BuildContext context) {
    // Esta página normalmente chega via pushReplacementNamed por cima de
    // NewTravelPage (WaitingPage -> Tracking é uma substituição, não um
    // push novo) — a pilha de navegação ainda tem NewTravelPage embaixo. Um
    // pop simples (header ou gesto do sistema) caía nela, permitindo pedir
    // uma segunda corrida por cima da que já está em andamento. Por isso o
    // voltar aqui sempre vai direto pra Home, nunca faz pop normal.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _returnToHome();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: Text(
            'Minha Viagem',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.moto.textPrimary),
          ),
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: context.moto.textPrimary),
            onPressed: _returnToHome,
          ),
          actions: [
            BlocBuilder<TravelTrackingBloc, TravelTrackingState>(
              buildWhen: (previous, current) =>
                  (previous is TravelTrackingAccepted) !=
                  (current is TravelTrackingAccepted),
              builder: (context, state) {
                if (state is! TravelTrackingAccepted) {
                  return const SizedBox.shrink();
                }
                return ValueListenableBuilder<int>(
                  valueListenable: Modular.get<ChatSession>().unread,
                  builder: (context, unread, _) {
                    if (unread <= 0) return const SizedBox.shrink();
                    return IconButton(
                      key: const Key('header-chat-button'),
                      tooltip:
                          '$unread mensagem${unread == 1 ? '' : 's'} nova${unread == 1 ? '' : 's'}',
                      onPressed: _openChat,
                      icon: Badge(
                        key: const Key('header-chat-unread-badge'),
                        backgroundColor: context.moto.danger,
                        label: Text(unread > 99 ? '99+' : '$unread'),
                        child: Icon(
                          Icons.notifications_rounded,
                          color: context.moto.danger,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: BlocListener<TravelTrackingBloc, TravelTrackingState>(
          // Todos os estados: além do mapa, o chat (spec pickup-chat-call) só
          // existe em Accepted e precisa parar nos demais.
          listenWhen: (previous, current) => true,
          listener: (context, state) {
            final chatSession = Modular.get<ChatSession>();
            if (state is TravelTrackingAccepted) {
              chatSession.start(state.travelId);
            } else {
              chatSession.stop();
            }
            if (state is TravelTrackingCompleted ||
                state is TravelTrackingCancelled) {
              unawaited(WakelockPlus.disable());
              unawaited(
                Modular.get<PassengerBackgroundLocationService>().stop(),
              );
            }

            final lat = switch (state) {
              TravelTrackingAccepted(:final driverLatitude) => driverLatitude,
              TravelTrackingInProgress(:final driverLatitude) => driverLatitude,
              _ => null,
            };
            final lng = switch (state) {
              TravelTrackingAccepted(:final driverLongitude) => driverLongitude,
              TravelTrackingInProgress(:final driverLongitude) =>
                driverLongitude,
              _ => null,
            };

            if (lat != null && lng != null) {
              _followDriverOnMap(LatLng(lat, lng));
            }
          },
          child: BlocBuilder<TravelTrackingBloc, TravelTrackingState>(
            builder: (context, state) {
              return switch (state) {
                TravelTrackingInitial() => const Center(
                  child: CircularProgressIndicator(),
                ),
                TravelTrackingLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
                TravelTrackingPending() => _buildPendingState(),
                TravelTrackingAccepted(
                  driver: final driver,
                  driverLatitude: final lat,
                  driverLongitude: final lng,
                  destinationLatitude: final destLat,
                  destinationLongitude: final destLng,
                  distanceToDestinationMeters: final dist,
                  remainingTimeMinutes: final time,
                  routePolyline: final polyline,
                  requestedAt: final requestedAt,
                  pickupProximity: final pickupProximity,
                ) =>
                  _buildAcceptedState(
                    driver,
                    driverLat: lat,
                    driverLng: lng,
                    destLat: destLat,
                    destLng: destLng,
                    distanceToDestinationMeters: dist,
                    remainingTimeMinutes: time,
                    routePolyline: polyline,
                    requestedAt: requestedAt,
                    pickupProximity: pickupProximity,
                  ),
                TravelTrackingInProgress(
                  driver: final driver,
                  driverLatitude: final lat,
                  driverLongitude: final lng,
                  destinationLatitude: final destLat,
                  destinationLongitude: final destLng,
                  distanceToDestinationMeters: final dist,
                  remainingTimeMinutes: final time,
                  routePolyline: final polyline,
                  requestedAt: final requestedAt,
                ) =>
                  _buildInProgressState(
                    driver,
                    driverLat: lat,
                    driverLng: lng,
                    destLat: destLat,
                    destLng: destLng,
                    distanceToDestinationMeters: dist,
                    remainingTimeMinutes: time,
                    routePolyline: polyline,
                    requestedAt: requestedAt,
                  ),
                TravelTrackingCompleted() => _buildCompletedState(),
                TravelTrackingCancelled(
                  reason: final reason,
                  cancelledByRole: final cancelledByRole,
                ) =>
                  _buildCancelledState(reason, cancelledByRole),
                TravelTrackingFailure(message: final msg) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.wifi_off_rounded,
                          size: 48,
                          color: context.moto.danger,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Não foi possível atualizar a viagem',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.moto.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          msg,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.moto.textSecondary),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => context
                              .read<TravelTrackingBloc>()
                              .add(LoadTravel(widget.travelId)),
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  ),
                ),
              };
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    try {
      Modular.get<ChatSession>().stop();
    } catch (_) {
      // Módulo já descartado: nada a parar.
    }
    WidgetsBinding.instance.removeObserver(this);
    _orderAcceptedSub?.cancel();
    _travelStartedSub?.cancel();
    _travelCompletedSub?.cancel();
    _travelCancelledSub?.cancel();
    _orderCancelledSub?.cancel();
    _driverLocationSub?.cancel();
    _distanceUpdateSub?.cancel();
    _driverNearbySub?.cancel();
    _driverArrivedSub?.cancel();
    _mapController?.dispose();
    Modular.get<SignalRService>().disconnectAll();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    WidgetsBinding.instance.addObserver(this);
    // Delay to ensure BlocProvider ancestor is established
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectAndLoad();
      if (mounted) {
        Modular.get<PassengerBackgroundLocationService>()
            .requestPermissionAndStart(context);
      }
    });
    _loadMyLocation();
    _loadDriverMarkerIcon();
  }

  Future<void> _loadDriverMarkerIcon() async {
    const size = 112.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = const Offset(size / 2, size / 2);

    canvas.drawCircle(
      center,
      50,
      Paint()..color = const Color(0xFF1F4FE0),
    );
    canvas.drawCircle(
      center,
      47,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );

    final carPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final car = Path()
      ..moveTo(27, 61)
      ..lineTo(34, 43)
      ..quadraticBezierTo(37, 36, 45, 36)
      ..lineTo(67, 36)
      ..quadraticBezierTo(75, 36, 78, 43)
      ..lineTo(85, 61)
      ..quadraticBezierTo(90, 64, 90, 70)
      ..lineTo(90, 77)
      ..quadraticBezierTo(90, 82, 85, 82)
      ..lineTo(79, 82)
      ..quadraticBezierTo(75, 82, 75, 77)
      ..lineTo(37, 77)
      ..quadraticBezierTo(37, 82, 33, 82)
      ..lineTo(27, 82)
      ..quadraticBezierTo(22, 82, 22, 77)
      ..lineTo(22, 70)
      ..quadraticBezierTo(22, 64, 27, 61)
      ..close();
    canvas.drawPath(car, carPaint);
    canvas.drawCircle(
      const Offset(36, 68),
      5,
      Paint()..color = const Color(0xFF1F4FE0),
    );
    canvas.drawCircle(
      const Offset(76, 68),
      5,
      Paint()..color = const Color(0xFF1F4FE0),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (!mounted || bytes == null) return;
    setState(() {
      _driverMarkerIcon = BitmapDescriptor.bytes(
        bytes.buffer.asUint8List(),
        width: 44,
        height: 44,
      );
    });
  }

  // PSG-08: com o app em background, o SignalR desconecta e o polling do
  // bloc continuava rodando (rede/bateria desperdiçadas à toa). Ao voltar
  // pro foreground, reconecta e força um LoadTravel — o estado pode ter
  // avançado (corrida aceita/concluída) enquanto o app estava fora do ar e
  // nem SignalR nem o timer pausado teriam capturado isso.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      BlocProvider.of<TravelTrackingBloc>(context).add(const PollingPaused());
      Modular.get<SignalRService>().disconnectAll();
    } else if (state == AppLifecycleState.resumed) {
      Modular.get<PassengerBackgroundLocationService>()
          .requestPermissionAndStart(context);
      _connectAndLoad();
    }
  }

  Future<void> _loadMyLocation() async {
    final result = await Modular.get<LocationService>().getCurrentPosition();
    if (result.isGranted && result.position != null && mounted) {
      setState(() {
        _myLocation = LatLng(
          result.position!.latitude,
          result.position!.longitude,
        );
      });
      if (_lastDriverLat == null && _lastDriverLng == null) {
        unawaited(
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(_myLocation!, 15),
          ),
        );
      }
    }
  }

  void _recenterToMyLocation() {
    final position = _myLocation;
    if (position == null || _mapController == null) return;
    if (_driverCameraEnabled) {
      setState(() => _driverCameraEnabled = false);
    }
    _mapController!.animateCamera(CameraUpdate.newLatLngZoom(position, 15));
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    final lat = _lastDriverLat;
    final lng = _lastDriverLng;
    if (_driverCameraEnabled && lat != null && lng != null) {
      _followDriverOnMap(LatLng(lat, lng), force: true);
    } else if (lat == null && lng == null && _myLocation != null) {
      unawaited(
        controller.animateCamera(
          CameraUpdate.newLatLngZoom(_myLocation!, 15),
        ),
      );
    }
  }

  void _toggleDriverCamera() {
    setState(() => _driverCameraEnabled = !_driverCameraEnabled);
    if (_driverCameraEnabled) {
      final lat = _lastDriverLat;
      final lng = _lastDriverLng;
      if (lat != null && lng != null) {
        _followDriverOnMap(LatLng(lat, lng), force: true);
      }
    }
  }

  void _followDriverOnMap(LatLng position, {bool force = false}) {
    final previous = _lastDriverLat != null && _lastDriverLng != null
        ? LatLng(_lastDriverLat!, _lastDriverLng!)
        : null;
    final moved = previous == null || previous != position;

    if (previous != null && moved) {
      _lastDriverBearing = _bearingBetween(previous, position);
    }
    _lastDriverLat = position.latitude;
    _lastDriverLng = position.longitude;

    final controller = _mapController;
    if (controller == null || !_driverCameraEnabled || (!moved && !force)) {
      return;
    }
    unawaited(
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: position,
            zoom: 18,
            tilt: 55,
            bearing: _lastDriverBearing,
          ),
        ),
      ),
    );
  }

  double _bearingBetween(LatLng from, LatLng to) {
    final fromLat = from.latitude * math.pi / 180;
    final toLat = to.latitude * math.pi / 180;
    final deltaLng = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(deltaLng) * math.cos(toLat);
    final x =
        math.cos(fromLat) * math.sin(toLat) -
        math.sin(fromLat) * math.cos(toLat) * math.cos(deltaLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  Widget _buildWithMap({
    required Widget infoOverlay,
    double? driverLat,
    double? driverLng,
    double? destLat,
    double? destLng,
    String? routePolyline,
  }) {
    final centerLat =
        driverLat ?? _myLocation?.latitude ?? destLat ?? -15.793889;
    final centerLng =
        driverLng ?? _myLocation?.longitude ?? destLng ?? -47.882778;

    final markers = <Marker>{};
    if (driverLat != null && driverLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: LatLng(driverLat, driverLng),
          icon:
              _driverMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Motorista'),
        ),
      );
    }
    if (destLat != null && destLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(destLat, destLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Destino'),
        ),
      );
    }

    final polylines = <Polyline>{};
    if (routePolyline != null && routePolyline.isNotEmpty) {
      polylines.addAll(
        MotoMapRouteStyle.polylines(
          id: 'route',
          points: decodePolyline(routePolyline),
        ),
      );
    }

    return Stack(
      children: [
        GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(
            target: LatLng(centerLat, centerLng),
            zoom: 16,
          ),
          markers: markers,
          polylines: polylines,
          zoomControlsEnabled: false,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
        ),
        Positioned(
          right: 16,
          top: 16,
          child: Column(
            children: [
              FloatingActionButton(
                key: const Key('toggle-driver-navigation-camera'),
                heroTag: 'toggle-driver-navigation-camera',
                mini: true,
                backgroundColor: _driverCameraEnabled
                    ? context.moto.accent
                    : context.moto.bgBase,
                foregroundColor: _driverCameraEnabled
                    ? Colors.white
                    : context.moto.accent,
                onPressed: _toggleDriverCamera,
                tooltip: _driverCameraEnabled
                    ? 'Desativar acompanhamento do motorista'
                    : 'Acompanhar motorista',
                child: Icon(
                  _driverCameraEnabled
                      ? Icons.navigation
                      : Icons.navigation_outlined,
                ),
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                key: const Key('recenter-my-location'),
                heroTag: 'recenter-my-location',
                mini: true,
                backgroundColor: context.moto.bgBase,
                foregroundColor: context.moto.accent,
                onPressed: _recenterToMyLocation,
                tooltip: 'Minha localização',
                child: const Icon(Icons.my_location),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: infoOverlay,
        ),
      ],
    );
  }

  /// Bottom-sheet-styled panel (edge-to-edge, rounded top corners, drag
  /// handle) matching the "Resumo da Viagem" sheet shown when picking a
  /// destination — used for both Accepted and InProgress so the driver's
  /// info reads the same visual language throughout the trip.
  Widget _buildInfoSheet({
    required String title,
    required IconData titleIcon,
    required Color titleColor,
    String? subtitle,
    DriverInfoEntity? driver,
    DateTime? requestedAt,
    int? distanceToDestinationMeters,
    int? remainingTimeMinutes,
    bool showCancelButton = false,
    Widget? extraAction,
  }) {
    return GestureDetector(
      key: const Key('passenger-travel-info-panel'),
      behavior: HitTestBehavior.opaque,
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 120) return;
        final expanded = velocity < 0;
        if (expanded != _travelPanelExpanded) {
          setState(() => _travelPanelExpanded = expanded);
        }
      },
      child: AnimatedSize(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
        child: MotoGlass(
          level: GlassLevel.sheet,
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            _travelPanelExpanded ? 20 : 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: context.moto.borderDefault,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  MotoTile(icon: titleIcon, accent: true, size: 40),
                  const SizedBox(width: MotoSpace.s3),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              if (_travelPanelExpanded && subtitle != null) ...[
                const SizedBox(height: 6),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
              if (driver != null) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    MotoAvatar(
                      initials: _initialsOf(driver.fullName),
                      size: 48,
                      image:
                          driver.photoUrl != null && driver.photoUrl!.isNotEmpty
                          ? NetworkImage(
                              _resolveImageUrl(driver.photoUrl!),
                              headers: _authHeaders,
                            )
                          : null,
                    ),
                    const SizedBox(width: MotoSpace.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driver.fullName,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          if (_travelPanelExpanded &&
                              driver.travelCount != null)
                            Text(
                              '${driver.travelCount} viagem${driver.travelCount == 1 ? '' : 's'} realizada${driver.travelCount == 1 ? '' : 's'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_travelPanelExpanded && driver.vehicleModel != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.directions_car,
                        color: context.moto.accent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          [
                                if (driver.vehicleBrand != null)
                                  driver.vehicleBrand,
                                driver.vehicleModel,
                              ].join(' ') +
                              (driver.vehiclePlate != null
                                  ? ' · ${driver.vehiclePlate}'
                                  : ''),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
              if (_travelPanelExpanded && requestedAt != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.event_note,
                      color: context.moto.accent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Solicitada às ${_formatTime(requestedAt)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
              if (_travelPanelExpanded &&
                  (distanceToDestinationMeters != null ||
                      remainingTimeMinutes != null)) ...[
                const SizedBox(height: MotoSpace.s3),
                MotoMetrics(
                  items: [
                    if (distanceToDestinationMeters != null)
                      (
                        (distanceToDestinationMeters / 1000).toStringAsFixed(1),
                        'km',
                        'Distância',
                      ),
                    if (remainingTimeMinutes != null)
                      ('$remainingTimeMinutes', 'min', 'Chegada estimada'),
                  ],
                ),
              ],
              if (_travelPanelExpanded && extraAction != null) ...[
                const SizedBox(height: MotoSpace.s3),
                extraAction,
              ],
              if (_travelPanelExpanded && showCancelButton) ...[
                const SizedBox(height: MotoSpace.s4),
                MotoButton(
                  label: 'Cancelar viagem',
                  variant: MotoButtonVariant.danger,
                  large: false,
                  onPressed: _cancelTravel,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Abre o chat temporário da viagem (spec pickup-chat-call).
  Future<void> _openChat() async {
    final session = Modular.get<ChatSession>();
    session.setChatOpen(true);
    try {
      await Modular.to.pushNamed(
        '/chat/',
        arguments: {
          'travelId': widget.travelId,
          'title': 'Chat com o motorista',
        },
      );
    } finally {
      session.setChatOpen(false);
      unawaited(session.refresh());
    }
  }

  Widget _buildAcceptedState(
    DriverInfoEntity? driver, {
    double? driverLat,
    double? driverLng,
    double? destLat,
    double? destLng,
    int? distanceToDestinationMeters,
    int? remainingTimeMinutes,
    String? routePolyline,
    DateTime? requestedAt,
    PickupProximity pickupProximity = PickupProximity.none,
  }) {
    final (title, titleIcon) = switch (pickupProximity) {
      PickupProximity.arrived => ('Motorista chegou!', Icons.place),
      PickupProximity.nearby => ('Motorista próximo!', Icons.near_me),
      PickupProximity.none => ('Motorista a caminho!', Icons.check_circle),
    };
    final infoSheet = _buildInfoSheet(
      title: title,
      titleIcon: titleIcon,
      titleColor: context.moto.success,
      driver: driver,
      requestedAt: requestedAt,
      distanceToDestinationMeters: distanceToDestinationMeters,
      remainingTimeMinutes: remainingTimeMinutes,
      showCancelButton: true,
      extraAction: ChatActionButton(
        session: Modular.get<ChatSession>(),
        onPressed: _openChat,
        label: 'Chat com o motorista',
      ),
    );

    return _buildWithMap(
      infoOverlay: infoSheet,
      driverLat: driverLat,
      driverLng: driverLng,
      destLat: destLat,
      destLng: destLng,
      routePolyline: routePolyline,
    );
  }

  Widget _buildCancelledState(String? reason, String? cancelledByRole) {
    return MotoCanvas(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cancel, size: 64, color: context.moto.danger),
              const SizedBox(height: 16),
              Text(
                'Viagem cancelada',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _cancelledByMessage(cancelledByRole),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (reason != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Motivo: $reason',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 32),
              MotoButton(
                label: 'Voltar para o início',
                large: false,
                expand: false,
                onPressed: _goHome,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _cancelledByMessage(String? role) => switch (role) {
    'Driver' => 'A viagem foi cancelada pelo motorista.',
    'Passenger' => 'A viagem foi cancelada pelo passageiro.',
    'Administrator' => 'A viagem foi cancelada pelo administrador.',
    _ => 'A viagem foi cancelada.',
  };

  Widget _buildCompletedState() {
    return MotoCanvas(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MotoSuccessCheck(),
              const SizedBox(height: 24),
              Text(
                'Viagem concluída!',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 32),
              MotoButton(
                label: 'Voltar para o início',
                large: false,
                expand: false,
                onPressed: _goHome,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInProgressState(
    DriverInfoEntity? driver, {
    double? driverLat,
    double? driverLng,
    double? destLat,
    double? destLng,
    int? distanceToDestinationMeters,
    int? remainingTimeMinutes,
    String? routePolyline,
    DateTime? requestedAt,
  }) {
    final infoSheet = _buildInfoSheet(
      title: 'Viagem em andamento',
      titleIcon: Icons.directions_car,
      titleColor: context.moto.accent,
      subtitle: 'Seu motorista está a caminho do destino.',
      driver: driver,
      requestedAt: requestedAt,
      distanceToDestinationMeters: distanceToDestinationMeters,
      remainingTimeMinutes: remainingTimeMinutes,
      showCancelButton: true,
    );

    return _buildWithMap(
      infoOverlay: infoSheet,
      driverLat: driverLat,
      driverLng: driverLng,
      destLat: destLat,
      destLng: destLng,
      routePolyline: routePolyline,
    );
  }

  Widget _buildPendingState() {
    return MotoCanvas(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MotoSonar(),
              const SizedBox(height: 24),
              Text(
                'Aguardando motorista...',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Sua viagem foi solicitada e está sendo enviada aos motoristas disponíveis.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              MotoButton(
                label: 'Cancelar viagem',
                variant: MotoButtonVariant.danger,
                large: false,
                expand: false,
                onPressed: _cancelTravel,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cancelTravel() async {
    var value = '';
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            scrollable: true,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            title: const Text('Cancelar viagem'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Informe o motivo do cancelamento. Esta informação será registrada no histórico da viagem.',
                ),
                const SizedBox(height: 16),
                TextField(
                  autofocus: true,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 300,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Motivo do cancelamento',
                    hintText: 'Descreva o motivo...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (text) => setDialogState(
                    () => value = text.trim(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Voltar'),
              ),
              TextButton(
                onPressed: value.isEmpty
                    ? null
                    : () => Navigator.of(ctx).pop(value),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(ctx).colorScheme.error,
                  disabledForegroundColor: Colors.grey.shade500,
                ),
                child: const Text('Confirmar cancelamento'),
              ),
            ],
          );
        },
      ),
    );

    if (reason == null || reason.isEmpty || !mounted) return;

    BlocProvider.of<TravelTrackingBloc>(
      context,
    ).add(CancelTravel(widget.travelId, reason));
  }

  String _resolveImageUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '${AppConfig.getBaseUrl()}$url';
  }

  Map<String, String>? get _authHeaders {
    final token = _authToken;
    if (token == null) return null;
    return {'Authorization': 'Bearer $token'};
  }

  String _initialsOf(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    final first = parts.first.characters.first;
    final last = parts.length > 1 ? parts.last.characters.first : '';
    return (first + last).toUpperCase();
  }

  Future<void> _connectAndLoad() async {
    // PSG-08: chamado de novo em cada retorno ao foreground — sem cancelar
    // as antigas primeiro, cada resume empilhava mais um listener duplicado
    // nos streams do SignalR (o serviço é singleton, sobrevive ao
    // disconnectAll do pause anterior).
    _orderAcceptedSub?.cancel();
    _travelStartedSub?.cancel();
    _travelCompletedSub?.cancel();
    _travelCancelledSub?.cancel();
    _orderCancelledSub?.cancel();
    _driverLocationSub?.cancel();
    _distanceUpdateSub?.cancel();
    _driverNearbySub?.cancel();
    _driverArrivedSub?.cancel();

    final token = await AuthStorage().getToken();
    _authToken = token;
    if (mounted) setState(() {});
    if (token == null) {
      if (mounted) {
        BlocProvider.of<TravelTrackingBloc>(
          context,
        ).add(LoadTravel(widget.travelId));
      }
      return;
    }

    final baseUrl = AppConfig.getBaseUrl();
    final signalR = Modular.get<SignalRService>();
    final bloc = BlocProvider.of<TravelTrackingBloc>(context);

    // Register stream listeners BEFORE connecting to avoid race condition:
    // if the backend emits an event between connect() and listen(), the
    // broadcast stream would drop it since it has no buffer.
    _orderAcceptedSub = signalR.onOrderAccepted.listen((data) {
      if (data['travelId'] == widget.travelId) {
        bloc.add(TravelOrderAccepted(data));
      }
    });
    _travelStartedSub = signalR.onTravelStarted.listen((data) {
      if (data['travelId'] == widget.travelId) bloc.add(TravelStarted(data));
    });
    _travelCompletedSub = signalR.onTravelCompleted.listen((data) {
      if (data['travelId'] == widget.travelId) bloc.add(TravelCompleted(data));
    });
    _travelCancelledSub = signalR.onTravelCancelled.listen((data) {
      if (data['travelId'] == widget.travelId) bloc.add(TravelCancelled(data));
    });
    _orderCancelledSub = signalR.onOrderCancelled.listen((data) {
      if (data['orderId'] == widget.orderId) {
        bloc.add(TravelCancelled(data));
      }
    });
    _driverLocationSub = signalR.onDriverLocationUpdated.listen((data) {
      if (data['travelId'] == widget.travelId) {
        bloc.add(DriverLocationUpdated(data));
      }
    });
    _distanceUpdateSub = signalR.onDistanceUpdate.listen((data) {
      if (data['travelId'] == widget.travelId) bloc.add(DistanceUpdated(data));
    });
    _driverNearbySub = signalR.onDriverNearby.listen((data) {
      if (data['travelId'] == widget.travelId) {
        bloc.add(DriverProximityAlerted(data));
      }
    });
    _driverArrivedSub = signalR.onDriverArrived.listen((data) {
      if (data['travelId'] == widget.travelId) {
        bloc.add(DriverProximityAlerted(data));
      }
    });

    try {
      await Future.wait([
        signalR.connect('travel-orders', '$baseUrl/hubs/travel-orders', token),
        signalR.connect(
          'travel-management',
          '$baseUrl/hubs/travel-management',
          token,
        ),
      ]);
    } catch (_) {
      // Fallback: polling will handle updates
    }

    if (mounted) {
      try {
        final bloc2 = BlocProvider.of<TravelTrackingBloc>(context);
        bloc2.add(LoadTravel(widget.travelId));
      } catch (_) {
        debugPrint('Não foi possível atualizar o acompanhamento da viagem.');
      }
    }
  }

  void _goHome() {
    Modular.get<TravelLocalRepository>().clearTravels();
    Modular.to.navigate('/home');
  }

  /// Volta pra Home sem limpar o cache de viagens — usado pelo botão/gesto
  /// de voltar enquanto a viagem ainda está em andamento (Accepted/
  /// InProgress); diferente de [_goHome], que só faz sentido quando a
  /// viagem já terminou (Completed/Cancelled).
  void _returnToHome() {
    Modular.to.navigate('/home');
  }
}
