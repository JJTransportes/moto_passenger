// ignore_for_file: must_be_immutable

import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' hide ReadContext;
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:moto_passenger/core/auth/auth_storage.dart';
import 'package:moto_passenger/core/location/location_service.dart';
import 'package:moto_passenger/design_system/design_system.dart';
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
  final ValueNotifier<bool> _hasPriorityAccess = ValueNotifier(false);

  OrderType _orderType = OrderType.normal;

  LatLng? _currentLocation;
  Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  // Enquanto true, toques no mapa são ignorados — evita abrir várias
  // "Resumo da Viagem" empilhadas ao tocar em vários pontos antes da
  // primeira rota calculada terminar/fechar.
  bool _isSelectingDestination = false;

  // PSG-02: defesa em profundidade, independente do bloc — o PSG-01 já
  // corrige a causa raiz do travamento (status `timeout` gera diálogo com
  // mensagem clara), mas se por qualquer outro motivo nenhum estado
  // terminal chegar (evento perdido, exceção não mapeada), o mapa ficava
  // preso no spinner de "carregando" pra sempre, sem saída pro usuário.
  static const _mapLoadTimeout = Duration(seconds: 15);
  Timer? _mapTimeoutTimer;
  bool _mapTimedOut = false;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NewTravelBloc, NewTravelState>(
      listener: (context, state) {
        switch (state) {
          case NewTravelPendingOrder(:final orderId):
            _showPendingOrderModal(orderId);
          case NewTravelActiveOrder(:final travelId):
            // Redirect to tracking for active travels.
            // `Navigator.of(context)` é o Navigator imperativo puro do
            // Flutter — num app com flutter_modular (Router API
            // declarativo), não passa `arguments` pelo canal que a rota
            // `/tracking` lê (`Modular.args.data`). A tela de tracking abria
            // sem saber o `travelId`, ficando presa no spinner até um evento
            // de SignalR forçar uma transição de estado — daí o "toda vez
            // que abre o app com viagem em andamento, o mapa fica
            // carregando e só um tempo depois aparece Tentar novamente".
            Modular.to.pushReplacementNamed(
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
            setState(() => _isSelectingDestination = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: context.moto.danger,
              ),
            );
          default:
            break;
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: Text('Nova Viagem', style: TextStyle(color: context.moto.textPrimary)),
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: context.moto.textPrimary),
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
    _mapTimeoutTimer?.cancel();
    _destinationController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Check for pending orders first, then proceed to normal flow
    BlocProvider.of<NewTravelBloc>(context).add(const CheckPendingOrder());
    _startMapTimeoutTimer();

    Future.microtask(() async {
      await _verifyPriorityAccess();
    });
  }

  void _startMapTimeoutTimer() {
    _mapTimeoutTimer?.cancel();
    _mapTimeoutTimer = Timer(_mapLoadTimeout, () {
      if (!mounted || _currentLocation != null) return;
      setState(() => _mapTimedOut = true);
    });
  }

  void _retryMapLoad() {
    setState(() => _mapTimedOut = false);
    _startMapTimeoutTimer();
    BlocProvider.of<NewTravelBloc>(context).add(const GetCurrentLocation());
  }

  void _recenterToCurrentLocation() {
    final position = _currentLocation;
    if (position == null || _mapController == null) return;
    _mapController!.animateCamera(CameraUpdate.newLatLngZoom(position, 15));
  }

  Future<void> _verifyPriorityAccess() async {
    try {
      final dio = Modular.get<Dio>();
      final authStorage = Modular.get<AuthStorage>();
      final userId = await authStorage.getUserId();

      final response = await dio.get('/api/passengers/$userId/priority');

      _hasPriorityAccess.value = response.statusCode == HttpStatus.ok;
    } on DioException catch (e) {
      log(e.message ?? "");
      return;
    }
  }

  Widget _buildMap(NewTravelState state) {
    if (_mapTimedOut && _currentLocation == null) {
      return Container(
        color: context.moto.bgSunken,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.map_outlined, size: 48, color: context.moto.textTertiary),
                const SizedBox(height: 16),
                Text(
                  'Não foi possível carregar o mapa.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.moto.textPrimary),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _retryMapLoad,
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (state is NewTravelCheckingPending || state is NewTravelLocationLoading) {
      return Container(
        color: context.moto.bgSunken,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentLocation != null) {
      return Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentLocation!,
              zoom: 15,
            ),
            markers: _markers,
            polylines: _polylines,
            onMapCreated: (controller) => _mapController = controller,
            onTap: _isSelectingDestination
                ? null
                : (latLng) {
                    setState(() => _isSelectingDestination = true);
                    BlocProvider.of<NewTravelBloc>(context).add(
                      CalculateRoute(latitude: latLng.latitude, longitude: latLng.longitude),
                    );
                  },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              heroTag: 'recenter-location',
              mini: true,
              backgroundColor: context.moto.bgBase,
              foregroundColor: context.moto.accent,
              onPressed: _recenterToCurrentLocation,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      );
    }

    return Container(
      color: context.moto.bgSunken,
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
              prefixIcon: Icon(Icons.search, color: context.moto.accent),
              filled: true,
              fillColor: context.moto.bgSunken,
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
                    leading: Icon(Icons.location_on, color: context.moto.accent),
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

    _mapTimeoutTimer?.cancel();
    setState(() {
      _mapTimedOut = false;
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
          if (status == LocationStatus.timeout)
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                BlocProvider.of<NewTravelBloc>(context).add(const GetCurrentLocation());
              },
              child: const Text('Tentar novamente'),
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
      builder: (_) => AnimatedBuilder(
        animation: _hasPriorityAccess,
        builder: (_, __) {
          return BlocProvider.value(
            value: BlocProvider.of<NewTravelBloc>(context),
            child: _RouteBottomSheetContent(
              route: route,
              distKm: distKm,
              hasPriorityAccess: _hasPriorityAccess.value,
              orderType: _orderType,
            ),
          );
        },
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _isSelectingDestination = false);
    });
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
                Icon(Icons.access_time, color: context.moto.warning, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Você já tem um pedido pendente',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.moto.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Existe um pedido de viagem aguardando motorista. '
              'O que você deseja fazer?',
              style: TextStyle(
                fontSize: 14,
                color: context.moto.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.moto.accent,
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
                child: Text(
                  'Aguardar motorista',
                  style: TextStyle(color: context.moto.textOnAccent, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: context.moto.danger),
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
                child: Text(
                  'Cancelar e criar novo',
                  style: TextStyle(color: context.moto.danger, fontSize: 16),
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
                child: Text(
                  'Voltar',
                  style: TextStyle(color: context.moto.textPrimary, fontSize: 16),
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

class _RouteBottomSheetContent extends StatefulWidget {
  final TravelRouteEntity route;
  final String distKm;
  bool hasPriorityAccess;
  OrderType orderType;

  _RouteBottomSheetContent({
    required this.route,
    required this.distKm,
    required this.hasPriorityAccess,
    required this.orderType,
  });

  @override
  State<_RouteBottomSheetContent> createState() => _RouteBottomSheetContentState();
}

class _RouteBottomSheetContentState extends State<_RouteBottomSheetContent> {
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
                    Icon(Icons.location_on, color: context.moto.accent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.route.destinationAddress,
                        style: TextStyle(color: context.moto.textPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.straighten, color: context.moto.accent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.distKm} km',
                      style: TextStyle(color: context.moto.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.timer_outlined, color: context.moto.accent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _formatTravelTime(widget.route.timeMinutes),
                      style: TextStyle(color: context.moto.textPrimary),
                    ),
                  ],
                ),
                Visibility(
                  visible: widget.hasPriorityAccess,
                  child: Row(
                    spacing: 16,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Switch(
                        value: widget.orderType == OrderType.priority,
                        onChanged: (value) {
                          widget.orderType = widget.orderType == OrderType.normal ? OrderType.priority : OrderType.normal;
                          setState(() {});
                        },
                      ),
                      Text(
                        'Pedido com prioridade',
                        style: TextStyle(color: context.moto.textPrimary),
                      ),
                    ],
                  ),
                ),
                if (isCreating) ...[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Solicitando viagem...',
                            style: TextStyle(
                              color: context.moto.textPrimary,
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
                            backgroundColor: context.moto.bgBase,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              side: BorderSide(color: context.moto.accent),
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
                              : Text(
                                  'Cancelar',
                                  style: TextStyle(color: context.moto.accent, fontSize: 16),
                                ),
                        ),
                      ),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isCreating ? context.moto.borderDefault : context.moto.accent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                          onPressed: isCreating
                              ? null
                              : () => BlocProvider.of<NewTravelBloc>(context).add(
                                  ConfirmTravel(
                                    originLat: widget.route.originLat,
                                    originLng: widget.route.originLng,
                                    destinationLat: widget.route.destinationLat,
                                    destinationLng: widget.route.destinationLng,
                                    orderType: widget.orderType,
                                  ),
                                ),
                          child: isCreating
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: context.moto.textOnAccent,
                                  ),
                                )
                              : Text(
                                  'Solicitar Viagem',
                                  style: TextStyle(color: context.moto.textOnAccent, fontSize: 16),
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

enum OrderType { normal, priority }
