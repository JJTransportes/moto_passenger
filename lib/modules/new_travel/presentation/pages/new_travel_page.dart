import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' hide ReadContext;
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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

  LatLng? _currentLocation;
  Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NewTravelBloc, NewTravelState>(
      listener: (context, state) {
        switch (state) {
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
    BlocProvider.of<NewTravelBloc>(context).add(const GetCurrentLocation());
  }

  Widget _buildMap(NewTravelState state) {
    if (state is NewTravelLocationLoading) {
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
                    const Icon(Icons.timer_outlined, color: Color(0xFF4685C0), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '($distKm km)',
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
