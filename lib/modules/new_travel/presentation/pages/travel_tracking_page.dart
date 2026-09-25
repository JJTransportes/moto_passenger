import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' hide ReadContext;
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:moto_passenger/core/auth/auth_storage.dart';
import 'package:moto_passenger/core/config/app_config.dart';
import 'package:moto_passenger/core/local_db/repositories/travel_local_repository.dart';
import 'package:moto_passenger/core/location/location_service.dart';
import 'package:moto_passenger/core/maps/polyline_decoder.dart';
import 'package:moto_passenger/core/network/signalr_service.dart';
import 'package:moto_passenger/design_system/design_system.dart';
import 'package:moto_passenger/modules/new_travel/domain/entities/travel_tracking_entity.dart';
import 'package:moto_passenger/modules/new_travel/presentation/blocs/travel_tracking_bloc.dart';
import 'package:moto_passenger/modules/new_travel/presentation/blocs/travel_tracking_event.dart';
import 'package:moto_passenger/modules/new_travel/presentation/blocs/travel_tracking_state.dart';

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

class _TravelTrackingPageState extends State<TravelTrackingPage> with WidgetsBindingObserver {
  StreamSubscription? _orderAcceptedSub;
  StreamSubscription? _travelStartedSub;
  StreamSubscription? _travelCompletedSub;
  StreamSubscription? _travelCancelledSub;
  StreamSubscription? _orderCancelledSub;
  StreamSubscription? _driverLocationSub;
  StreamSubscription? _distanceUpdateSub;

  GoogleMapController? _mapController;
  bool _isUserInteracting = false;
  double? _lastDriverLat;
  double? _lastDriverLng;
  String? _authToken;
  LatLng? _myLocation;

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
        appBar: AppBar(
          title: Text('Minha Viagem', style: TextStyle(color: context.moto.textPrimary)),
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: context.moto.textPrimary),
            onPressed: _returnToHome,
          ),
        ),
        body: BlocListener<TravelTrackingBloc, TravelTrackingState>(
        listenWhen: (previous, current) => current is TravelTrackingAccepted || current is TravelTrackingInProgress,
        listener: (context, state) {
          final lat = switch (state) {
            TravelTrackingAccepted(:final driverLatitude) => driverLatitude,
            TravelTrackingInProgress(:final driverLatitude) => driverLatitude,
            _ => null,
          };
          final lng = switch (state) {
            TravelTrackingAccepted(:final driverLongitude) => driverLongitude,
            TravelTrackingInProgress(:final driverLongitude) => driverLongitude,
            _ => null,
          };

          if (lat != null && lng != null && !_isUserInteracting && _mapController != null && (lat != _lastDriverLat || lng != _lastDriverLng)) {
            _lastDriverLat = lat;
            _lastDriverLng = lng;
            _mapController!.animateCamera(
              CameraUpdate.newLatLngZoom(LatLng(lat, lng), 14),
            );
          }
        },
        child: BlocBuilder<TravelTrackingBloc, TravelTrackingState>(
          builder: (context, state) {
            print('[DIAG] BlocBuilder rebuild, state=${state.runtimeType}, bloc hash=${BlocProvider.of<TravelTrackingBloc>(context).hashCode}');
            return switch (state) {
              TravelTrackingInitial() => const Center(child: CircularProgressIndicator()),
              TravelTrackingLoading() => const Center(child: CircularProgressIndicator()),
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
              TravelTrackingCancelled(reason: final reason) => _buildCancelledState(reason),
              TravelTrackingFailure(message: final msg) => Center(child: Text('Erro: $msg')),
            };
          },
        ),
      ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _orderAcceptedSub?.cancel();
    _travelStartedSub?.cancel();
    _travelCompletedSub?.cancel();
    _travelCancelledSub?.cancel();
    _orderCancelledSub?.cancel();
    _driverLocationSub?.cancel();
    _distanceUpdateSub?.cancel();
    _mapController?.dispose();
    Modular.get<SignalRService>().disconnectAll();
    print('[DIAG] TravelTrackingPage.dispose pageHash=$hashCode travelId=${widget.travelId}');
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    print('[DIAG] TravelTrackingPage.initState travelId=${widget.travelId} orderId=${widget.orderId} pageHash=$hashCode');
    WidgetsBinding.instance.addObserver(this);
    // Delay to ensure BlocProvider ancestor is established
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('[DIAG] postFrameCallback firing _connectAndLoad, pageHash=$hashCode, mounted=$mounted');
      _connectAndLoad();
    });
    _loadMyLocation();
  }

  // PSG-08: com o app em background, o SignalR desconecta e o polling do
  // bloc continuava rodando (rede/bateria desperdiçadas à toa). Ao voltar
  // pro foreground, reconecta e força um LoadTravel — o estado pode ter
  // avançado (corrida aceita/concluída) enquanto o app estava fora do ar e
  // nem SignalR nem o timer pausado teriam capturado isso.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      BlocProvider.of<TravelTrackingBloc>(context).add(const PollingPaused());
      Modular.get<SignalRService>().disconnectAll();
    } else if (state == AppLifecycleState.resumed) {
      _connectAndLoad();
    }
  }

  Future<void> _loadMyLocation() async {
    final result = await Modular.get<LocationService>().getCurrentPosition();
    if (result.isGranted && result.position != null && mounted) {
      setState(() {
        _myLocation = LatLng(result.position!.latitude, result.position!.longitude);
      });
    }
  }

  void _recenterToMyLocation() {
    final position = _myLocation;
    if (position == null || _mapController == null) return;
    _mapController!.animateCamera(CameraUpdate.newLatLngZoom(position, 15));
  }

  Widget _buildWithMap({
    required Widget infoOverlay,
    double? driverLat,
    double? driverLng,
    double? destLat,
    double? destLng,
    String? routePolyline,
  }) {
    final centerLat = driverLat ?? destLat ?? -23.5505;
    final centerLng = driverLng ?? destLng ?? -46.6333;

    final markers = <Marker>{};
    if (driverLat != null && driverLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: LatLng(driverLat, driverLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
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
      polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: decodePolyline(routePolyline),
          color: context.moto.accent,
          width: 4,
        ),
      );
    }

    return Stack(
      children: [
        GoogleMap(
          onMapCreated: (controller) => _mapController = controller,
          onCameraMoveStarted: () => _isUserInteracting = true,
          onCameraIdle: () => _isUserInteracting = false,
          initialCameraPosition: CameraPosition(
            target: LatLng(centerLat, centerLng),
            zoom: 14,
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
          child: FloatingActionButton(
            heroTag: 'recenter-my-location',
            mini: true,
            backgroundColor: context.moto.bgBase,
            foregroundColor: context.moto.accent,
            onPressed: _recenterToMyLocation,
            child: const Icon(Icons.my_location),
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
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.moto.bgBase,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, -2))],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
              Icon(titleIcon, color: titleColor),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle, style: TextStyle(color: context.moto.textPrimary)),
          ],
          if (driver != null) ...[
            const Divider(height: 24),
            Row(
              children: [
                _buildDriverAvatar(driver),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(driver.fullName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      if (driver.travelCount != null)
                        Text(
                          '${driver.travelCount} viagem${driver.travelCount == 1 ? '' : 's'} realizada${driver.travelCount == 1 ? '' : 's'}',
                          style: TextStyle(fontSize: 12, color: context.moto.textPrimary),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (driver.vehicleModel != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.directions_car, color: context.moto.accent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [
                        if (driver.vehicleBrand != null) driver.vehicleBrand,
                        driver.vehicleModel,
                      ].join(' ') + (driver.vehiclePlate != null ? ' · ${driver.vehiclePlate}' : ''),
                      style: TextStyle(fontSize: 14, color: context.moto.textPrimary),
                    ),
                  ),
                ],
              ),
            ],
          ],
          if (requestedAt != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.event_note, color: context.moto.accent, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Solicitada às ${_formatTime(requestedAt)}',
                  style: TextStyle(fontSize: 14, color: context.moto.textPrimary),
                ),
              ],
            ),
          ],
          if (distanceToDestinationMeters != null || remainingTimeMinutes != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (distanceToDestinationMeters != null) ...[
                  Icon(Icons.route, color: context.moto.accent, size: 20),
                  const SizedBox(width: 8),
                  Text('${(distanceToDestinationMeters / 1000).toStringAsFixed(1)} km', style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 16),
                ],
                if (remainingTimeMinutes != null) ...[
                  Icon(Icons.timer_outlined, color: context.moto.accent, size: 20),
                  const SizedBox(width: 8),
                  Text('Chegada estimada em $remainingTimeMinutes min', style: const TextStyle(fontSize: 14)),
                ],
              ],
            ),
          ],
          if (showCancelButton) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(side: BorderSide(color: context.moto.danger)),
                onPressed: _cancelTravel,
                child: Text('Cancelar Viagem', style: TextStyle(color: context.moto.danger)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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
  }) {
    final infoSheet = _buildInfoSheet(
      title: 'Motorista a caminho!',
      titleIcon: Icons.check_circle,
      titleColor: context.moto.success,
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

  Widget _buildCancelledState(String? reason) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cancel, size: 64, color: context.moto.danger),
            const SizedBox(height: 16),
            const Text('Viagem cancelada', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (reason != null) ...[
              const SizedBox(height: 8),
              Text(
                reason,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.moto.textPrimary),
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.moto.accent,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              onPressed: _goHome,
              child: Text('Voltar para Home', style: TextStyle(color: context.moto.textOnAccent)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.task_alt, size: 64, color: context.moto.success),
            const SizedBox(height: 16),
            const Text('Viagem concluída!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.moto.accent,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              onPressed: _goHome,
              child: Text('Voltar para Home', style: TextStyle(color: context.moto.textOnAccent)),
            ),
          ],
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.access_time, size: 64, color: context.moto.warning),
            const SizedBox(height: 16),
            const Text('Aguardando motorista...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Sua viagem foi solicitada e está sendo enviada aos motoristas disponíveis.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.moto.textPrimary),
            ),
            const SizedBox(height: 32),
            OutlinedButton(
              style: OutlinedButton.styleFrom(side: BorderSide(color: context.moto.danger)),
              onPressed: _cancelTravel,
              child: Text('Cancelar Viagem', style: TextStyle(color: context.moto.danger)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelTravel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar viagem'),
        content: const Text('Deseja realmente cancelar esta viagem?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Não'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sim, cancelar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    BlocProvider.of<TravelTrackingBloc>(context).add(CancelTravel(widget.travelId));
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

  Widget _buildDriverAvatar(DriverInfoEntity driver) {
    final photoUrl = driver.photoUrl;
    return CircleAvatar(
      radius: 20,
      backgroundColor: context.moto.accent.withAlpha(30),
      backgroundImage: photoUrl != null && photoUrl.isNotEmpty
          ? NetworkImage(_resolveImageUrl(photoUrl), headers: _authHeaders)
          : null,
      child: photoUrl == null || photoUrl.isEmpty
          ? Icon(Icons.person, color: context.moto.accent)
          : null,
    );
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

    final token = await AuthStorage().getToken();
    _authToken = token;
    if (mounted) setState(() {});
    if (token == null) {
      if (mounted) {
        BlocProvider.of<TravelTrackingBloc>(context).add(LoadTravel(widget.travelId));
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
      if (data['travelId'] == widget.travelId) bloc.add(TravelOrderAccepted(data));
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
      if (data['travelId'] == widget.travelId) bloc.add(DriverLocationUpdated(data));
    });
    _distanceUpdateSub = signalR.onDistanceUpdate.listen((data) {
      if (data['travelId'] == widget.travelId) bloc.add(DistanceUpdated(data));
    });

    try {
      await Future.wait([
        signalR.connect('travel-orders', '$baseUrl/hubs/travel-orders', token),
        signalR.connect('travel-management', '$baseUrl/hubs/travel-management', token),
      ]);
    } catch (_) {
      // Fallback: polling will handle updates
    }

    print('[DIAG] about to dispatch LoadTravel, mounted=$mounted, pageHash=$hashCode');
    if (mounted) {
      try {
        final bloc2 = BlocProvider.of<TravelTrackingBloc>(context);
        print('[DIAG] dispatching LoadTravel travelId=${widget.travelId} to bloc hash=${bloc2.hashCode} isClosed=${bloc2.isClosed}');
        bloc2.add(LoadTravel(widget.travelId));
      } catch (e, st) {
        print('[DIAG] EXCEPTION dispatching LoadTravel: $e\n$st');
      }
    } else {
      print('[DIAG] NOT mounted, skipping LoadTravel dispatch entirely! pageHash=$hashCode');
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
