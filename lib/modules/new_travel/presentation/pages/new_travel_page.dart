import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' hide ReadContext;
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:moto_passenger/core/auth/auth_storage.dart';
import 'package:moto_passenger/core/location/location_service.dart';
import 'package:moto_passenger/core/theme/app_theme.dart';
import 'package:moto_passenger/modules/new_travel/domain/entities/travel_route_entity.dart';
import 'package:moto_passenger/modules/new_travel/presentation/blocs/new_travel_bloc.dart';
import 'package:moto_passenger/modules/new_travel/presentation/blocs/new_travel_event.dart';
import 'package:moto_passenger/modules/new_travel/presentation/blocs/new_travel_state.dart';

class NewTravelPage extends StatefulWidget {
  const NewTravelPage({super.key});

  @override
  State<NewTravelPage> createState() => _NewTravelPageState();
}

class _NewTravelPageState extends State<NewTravelPage> {
  final _destinationController = TextEditingController();
  GoogleMapController? _mapController;
  bool _hasPriorityAccess = false;

  LatLng? _currentLocation;
  Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NewTravelBloc, NewTravelState>(
      listener: (context, state) {
        switch (state) {
          case NewTravelPendingOrder(:final orderId):
            _showPendingOrderModal(orderId);
          case NewTravelActiveOrder(:final travelId):
            // Redirect to tracking for active travels
            Navigator.of(context).pushReplacementNamed(
              '/new-travel/tracking',
              arguments: {'travelId': travelId},
            );
          case NewTravelLocationLoaded(:final position):
            _onLocationLoaded(position);
          case NewTravelLocationError(:final message, :final status):
            _showLocationErrorDialog(message, status);
          case NewTravelRouteReady(:final route):
            _showRouteBottomSheet(route);
          case NewTravelCreated(:final orderId):
            // Show success snackbar
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Pedido enviado!'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
            // Close bottom sheet before navigating
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
            Modular.to.pushNamed(
              '/new-travel/waiting',
              arguments: {
                'orderId': orderId,
              },
            );
          case NewTravelNoDriversAvailable(:final message):
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
            _showNoDriversDialog(message);
          case NewTravelFailure(:final message):
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: Colors.red,
              ),
            );
          default:
            break;
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.white,
          appBar: AppBar(
            title: const Text('Nova Viagem', style: TextStyle(color: Color(0xFF4E4E4E))),
            backgroundColor: AppColors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF4E4E4E)),
              onPressed: () => Modular.to.pop(),
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                _buildSearchBar(state),
                Expanded(child: _buildMap(state)),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Check for pending orders first, then proceed to normal flow
    BlocProvider.of<NewTravelBloc>(context).add(const CheckPendingOrder());

    Future.microtask(() async {
      await _verifyPriorityAccess();
    });
  }

  Future<void> _verifyPriorityAccess() async {
    try {
      final dio = Modular.get<Dio>();
      final authStorage = Modular.get<AuthStorage>();
      final userId = await authStorage.getUserId();

      final response = await dio.get('/api/passengers/$userId/priority');

      _hasPriorityAccess = response.statusCode == HttpStatus.ok;
    } on DioException catch (e) {
      log(e.message ?? "");
      return;
    }
  }

  Widget _buildMap(NewTravelState state) {
    if (state is NewTravelCheckingPending || state is NewTravelLocationLoading) {
      return Container(
        color: Colors.grey.shade200,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentLocation != null) {
      return GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _currentLocation!,
          zoom: 15,
        ),
        markers: _markers,
        polylines: _polylines,
        onMapCreated: (controller) => _mapController = controller,
        onTap: (latLng) {
          BlocProvider.of<NewTravelBloc>(context).add(
            CalculateRoute(latitude: latLng.latitude, longitude: latLng.longitude),
          );
        },
        myLocationEnabled: true,
        zoomControlsEnabled: false,
      );
    }

    return Container(
      color: Colors.grey.shade200,
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildSearchBar(NewTravelState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _destinationController,
            decoration: InputDecoration(
              hintText: 'Pra onde você quer ir?',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF4685C0)),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (query) {
              BlocProvider.of<NewTravelBloc>(context).add(SearchPlaces(query: query));
            },
          ),
          if (state is NewTravelPlacesLoaded && state.suggestions.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: state.suggestions.length,
                  itemBuilder: (_, i) => ListTile(
                    leading: const Icon(Icons.location_on, color: Color(0xFF4685C0)),
                    title: Text(
                      state.suggestions[i].address,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      _destinationController.text = state.suggestions[i].address;
                      BlocProvider.of<NewTravelBloc>(context).add(
                        SelectPlace(suggestion: state.suggestions[i]),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _onLocationLoaded(LatLng position) {
    if (!mounted) return;

    setState(() {
      _currentLocation = position;
      _markers = {
        Marker(
          markerId: const MarkerId('current_location'),
          position: position,
          infoWindow: const InfoWindow(title: 'Sua localização'),
        ),
      };
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(position, 15),
    );
  }

  Future<void> _showLocationErrorDialog(String message, LocationStatus status) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Localização necessária'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
          if (status == LocationStatus.serviceDisabled)
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await Modular.get<LocationService>().openLocationSettings();
                if (mounted) {
                  BlocProvider.of<NewTravelBloc>(context).add(const GetCurrentLocation());
                }
              },
              child: const Text('Ativar'),
            ),
          if (status == LocationStatus.deniedForever)
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await Modular.get<LocationService>().openAppSettings();
              },
              child: const Text('Configurações'),
            ),
        ],
      ),
    );
  }

  void _showRouteBottomSheet(TravelRouteEntity route) {
    final distKm = (route.distanceMeters / 1000).toStringAsFixed(1);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => BlocProvider.value(
        value: BlocProvider.of<NewTravelBloc>(context),
        child: _RouteBottomSheetContent(
          route: route,
          distKm: distKm,
        ),
      ),
    );
  }

  Future<void> _showNoDriversDialog(String message) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Nenhum motorista disponível'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPendingOrderModal(String orderId) {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.orange, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Você já tem um pedido pendente',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF4E4E4E),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Existe um pedido de viagem aguardando motorista. '
              'O que você deseja fazer?',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF4E4E4E),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4685C0),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Modular.to.pop();
                  Modular.to.pushNamed(
                    '/new-travel/waiting',
                    arguments: {'orderId': orderId},
                  );
                },
                child: const Text(
                  'Aguardar motorista',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  BlocProvider.of<NewTravelBloc>(context).add(
                    CancelPendingOrder(orderId: orderId),
                  );
                },
                child: const Text(
                  'Cancelar e criar novo',
                  style: TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Modular.to.pop();
                },
                child: const Text(
                  'Voltar',
                  style: TextStyle(color: Color(0xFF4E4E4E), fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Formata minutos totais em string legível para exibição.
/// Ex: 45 → "45 min", 75 → "1h 15min"
String _formatTravelTime(int totalMinutes) {
  if (totalMinutes < 60) {
    return '$totalMinutes min';
  }
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (minutes == 0) {
    return '${hours}h';
  }
  return '${hours}h ${minutes}min';
}

class _RouteBottomSheetContent extends StatelessWidget {
  final TravelRouteEntity route;
  final String distKm;

  const _RouteBottomSheetContent({
    required this.route,
    required this.distKm,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NewTravelBloc, NewTravelState>(
      builder: (context, state) {
        final isCreating = state is NewTravelCreating;

        return SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Resumo da Viagem',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Color(0xFF4685C0), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        route.destinationAddress,
                        style: const TextStyle(color: Color(0xFF4E4E4E)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.straighten, color: Color(0xFF4685C0), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '$distKm km',
                      style: const TextStyle(color: Color(0xFF4E4E4E)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: Color(0xFF4685C0), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _formatTravelTime(route.timeMinutes),
                      style: const TextStyle(color: Color(0xFF4E4E4E)),
                    ),
                  ],
                ),
                if (isCreating) ...[
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Solicitando viagem...',
                            style: TextStyle(
                              color: Color(0xFF4E4E4E),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                SizedBox(
                  width: MediaQuery.sizeOf(context).width,
                  child: Row(
                    spacing: 24,
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              side: BorderSide(color: AppColors.primary),
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                          onPressed: isCreating ? null : Modular.to.pop,
                          child: isCreating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Cancelar',
                                  style: TextStyle(color: AppColors.primary, fontSize: 16),
                                ),
                        ),
                      ),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isCreating ? Colors.grey : AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                          onPressed: isCreating
                              ? null
                              : () => BlocProvider.of<NewTravelBloc>(context).add(
                                  ConfirmTravel(
                                    originLat: route.originLat,
                                    originLng: route.originLng,
                                    destinationLat: route.destinationLat,
                                    destinationLng: route.destinationLng,
                                  ),
                                ),
                          child: isCreating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Solicitar Viagem',
                                  style: TextStyle(color: Colors.white, fontSize: 16),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
