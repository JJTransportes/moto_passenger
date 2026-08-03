import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' hide ReadContext;
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:moto_passenger/core/auth/auth_storage.dart';
import 'package:moto_passenger/core/config/app_config.dart';
import 'package:moto_passenger/core/local_db/repositories/travel_local_repository.dart';
import 'package:moto_passenger/core/network/signalr_service.dart';
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

class _TravelTrackingPageState extends State<TravelTrackingPage> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Minha Viagem', style: TextStyle(color: Color(0xFF4E4E4E))),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF4E4E4E)),
          onPressed: () => Modular.to.pop(),
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
              ) =>
                _buildAcceptedState(
                  driver,
                  driverLat: lat,
                  driverLng: lng,
                  destLat: destLat,
                  destLng: destLng,
                  distanceToDestinationMeters: dist,
                  remainingTimeMinutes: time,
                ),
              TravelTrackingInProgress(
                driverLatitude: final lat,
                driverLongitude: final lng,
                destinationLatitude: final destLat,
                destinationLongitude: final destLng,
                distanceToDestinationMeters: final dist,
                remainingTimeMinutes: final time,
              ) =>
                _buildInProgressState(
                  driverLat: lat,
                  driverLng: lng,
                  destLat: destLat,
                  destLng: destLng,
                  distanceToDestinationMeters: dist,
                  remainingTimeMinutes: time,
                ),
              TravelTrackingCompleted() => _buildCompletedState(),
              TravelTrackingCancelled(reason: final reason) => _buildCancelledState(reason),
              TravelTrackingFailure(message: final msg) => Center(child: Text('Erro: $msg')),
            };
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _orderAcceptedSub?.cancel();
    _travelStartedSub?.cancel();
    _travelCompletedSub?.cancel();
    _travelCancelledSub?.cancel();
    _orderCancelledSub?.cancel();
    _driverLocationSub?.cancel();
    _distanceUpdateSub?.cancel();
    _mapController?.dispose();
    Modular.get<SignalRService>().disconnectAll();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Delay to ensure BlocProvider ancestor is established
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectAndLoad();
    });
  }

  Widget _buildWithMap({
    required Widget infoOverlay,
    double? driverLat,
    double? driverLng,
    double? destLat,
    double? destLng,
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
          polylines: const {},
          zoomControlsEnabled: false,
          myLocationEnabled: false,
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: infoOverlay,
        ),
      ],
    );
  }

  Widget _buildAcceptedState(
    DriverInfoEntity? driver, {
    double? driverLat,
    double? driverLng,
    double? destLat,
    double? destLng,
    int? distanceToDestinationMeters,
    int? remainingTimeMinutes,
  }) {
    final infoCard = Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Motorista a caminho!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            if (driver != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person, color: Color(0xFF4685C0)),
                  const SizedBox(width: 8),
                  Text(driver.fullName, style: const TextStyle(fontSize: 14)),
                ],
              ),
              if (driver.vehicleModel != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.directions_car, color: Color(0xFF4685C0)),
                    const SizedBox(width: 8),
                    Text(
                      '${driver.vehicleModel}${driver.vehiclePlate != null ? " - ${driver.vehiclePlate}" : ""}',
                      style: const TextStyle(fontSize: 14, color: Color(0xFF4E4E4E)),
                    ),
                  ],
                ),
              ],
            ],
            if (distanceToDestinationMeters != null || remainingTimeMinutes != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (distanceToDestinationMeters != null) ...[
                    const Icon(Icons.route, color: Color(0xFF4685C0), size: 18),
                    const SizedBox(width: 4),
                    Text('${(distanceToDestinationMeters / 1000).toStringAsFixed(1)} km'),
                    const SizedBox(width: 12),
                  ],
                  if (remainingTimeMinutes != null) ...[
                    const Icon(Icons.timer_outlined, color: Color(0xFF4685C0), size: 18),
                    const SizedBox(width: 4),
                    Text('$remainingTimeMinutes min'),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
              onPressed: _cancelTravel,
              child: const Text('Cancelar Viagem', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );

    return _buildWithMap(
      infoOverlay: infoCard,
      driverLat: driverLat,
      driverLng: driverLng,
      destLat: destLat,
      destLng: destLng,
    );
  }

  Widget _buildCancelledState(String? reason) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cancel, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Viagem cancelada', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (reason != null) ...[
              const SizedBox(height: 8),
              Text(
                reason,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF4E4E4E)),
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4685C0),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              onPressed: _goHome,
              child: const Text('Voltar para Home', style: TextStyle(color: Colors.white)),
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
            const Icon(Icons.task_alt, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            const Text('Viagem concluída!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4685C0),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              onPressed: _goHome,
              child: const Text('Voltar para Home', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInProgressState({
    double? driverLat,
    double? driverLng,
    double? destLat,
    double? destLng,
    int? distanceToDestinationMeters,
    int? remainingTimeMinutes,
  }) {
    final infoCard = Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.directions_car, color: Color(0xFF4685C0)),
                SizedBox(width: 8),
                Text('Viagem em andamento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Seu motorista está a caminho do destino.', style: TextStyle(color: Color(0xFF4E4E4E))),
            if (distanceToDestinationMeters != null || remainingTimeMinutes != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (distanceToDestinationMeters != null) ...[
                    const Icon(Icons.route, color: Color(0xFF4685C0), size: 18),
                    const SizedBox(width: 4),
                    Text('${(distanceToDestinationMeters / 1000).toStringAsFixed(1)} km'),
                    const SizedBox(width: 12),
                  ],
                  if (remainingTimeMinutes != null) ...[
                    const Icon(Icons.timer_outlined, color: Color(0xFF4685C0), size: 18),
                    const SizedBox(width: 4),
                    Text('$remainingTimeMinutes min'),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );

    return _buildWithMap(
      infoOverlay: infoCard,
      driverLat: driverLat,
      driverLng: driverLng,
      destLat: destLat,
      destLng: destLng,
    );
  }

  Widget _buildPendingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.access_time, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            const Text('Aguardando motorista...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Sua viagem foi solicitada e está sendo enviada aos motoristas disponíveis.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF4E4E4E)),
            ),
            const SizedBox(height: 32),
            OutlinedButton(
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
              onPressed: _cancelTravel,
              child: const Text('Cancelar Viagem', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  void _cancelTravel() {
    context.read<TravelTrackingBloc>().add(CancelTravel(widget.travelId));
  }

  Future<void> _connectAndLoad() async {
    final token = await AuthStorage().getToken();
    if (token == null) {
      if (mounted) {
        context.read<TravelTrackingBloc>().add(LoadTravel(widget.travelId));
      }
      return;
    }

    final baseUrl = AppConfig.getBaseUrl();
    final signalR = Modular.get<SignalRService>();
    final bloc = context.read<TravelTrackingBloc>();

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

    if (mounted) {
      try {
        context.read<TravelTrackingBloc>().add(LoadTravel(widget.travelId));
      } catch (_) {
        // Bloc not available — page will show initial state
      }
    }
  }

  void _goHome() {
    Modular.get<TravelLocalRepository>().clearTravels();
    Modular.to.navigate('/home');
  }
}
