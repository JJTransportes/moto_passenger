// ignore_for_file: must_be_immutable

import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' hide ReadContext;
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:moto_passenger/core/auth/auth_storage.dart';
import 'package:moto_passenger/core/location/location_service.dart';
import 'package:moto_passenger/core/maps/i_places_autocomplete_service.dart';
import 'package:moto_passenger/core/maps/places_autocomplete_service.dart';
import 'package:moto_passenger/core/maps/polyline_decoder.dart';
import 'package:moto_passenger/design_system/design_system.dart';
import 'package:moto_passenger/modules/new_travel/domain/entities/travel_route_entity.dart';
import 'package:moto_passenger/modules/new_travel/presentation/blocs/new_travel_bloc.dart';
import 'package:moto_passenger/modules/new_travel/presentation/blocs/new_travel_event.dart';
import 'package:moto_passenger/modules/new_travel/presentation/blocs/new_travel_state.dart';

enum _PickupSelectionMode { destination, address, map }

class NewTravelPage extends StatefulWidget {
  const NewTravelPage({super.key});

  @override
  State<NewTravelPage> createState() => _NewTravelPageState();
}

class _NewTravelPageState extends State<NewTravelPage> {
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _originFocusNode = FocusNode();
  GoogleMapController? _mapController;
  final ValueNotifier<bool> _hasPriorityAccess = ValueNotifier(false);

  final OrderType _orderType = OrderType.normal;

  LatLng? _currentLocation;
  LatLng? _previewedPickup;
  String? _previewedPickupAddress;
  bool _showPickupConfirmation = false;
  int _pickupPreviewRequestId = 0;
  LatLng? _previewedDestination;
  String? _previewedDestinationAddress;
  bool _showDestinationConfirmation = false;
  BitmapDescriptor? _destinationFlagIcon;
  int _destinationPreviewRequestId = 0;
  Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  // Enquanto true, toques no mapa são ignorados — evita abrir várias
  // "Resumo da Viagem" empilhadas ao tocar em vários pontos antes da
  // primeira rota calculada terminar/fechar.
  bool _isSelectingDestination = false;
  bool _isConfirmingPickup = false;
  bool _searchingOrigin = false;
  _PickupSelectionMode _pickupSelectionMode = _PickupSelectionMode.destination;
  bool _isRouteBottomSheetOpen = false;
  Future<dynamic>? _routeBottomSheetClosed;

  // PSG-02: defesa em profundidade, independente do bloc — o PSG-01 já
  // corrige a causa raiz do travamento (status `timeout` gera diálogo com
  // mensagem clara), mas se por qualquer outro motivo nenhum estado
  // terminal chegar (evento perdido, exceção não mapeada), o mapa ficava
  // preso no spinner de "carregando" pra sempre, sem saída pro usuário.
  static const _mapLoadTimeout = Duration(seconds: 15);
  static const _searchDebounceDuration = Duration(milliseconds: 400);
  Timer? _mapTimeoutTimer;
  Timer? _searchDebounceTimer;
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
          case NewTravelOriginSelected(:final position, :final address):
            _onOriginSelected(position, address);
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
            unawaited(_handleNoDriversAvailable(message));
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
            title: Text(
              'Nova Viagem',
              style: TextStyle(color: context.moto.textPrimary),
            ),
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
    _searchDebounceTimer?.cancel();
    _originController.dispose();
    _destinationController.dispose();
    _originFocusNode.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Localização e verificação de pedido são independentes. Antes, o mapa
    // só começava a carregar depois que /orders/latest respondesse; após uma
    // viagem concluída essa consulta podia ficar pendente e prender a segunda
    // solicitação no spinner. O mapa agora começa imediatamente, enquanto a
    // retomada de uma viagem ativa é verificada em paralelo.
    final bloc = BlocProvider.of<NewTravelBloc>(context);
    bloc.add(const GetCurrentLocation());
    bloc.add(const CheckPendingOrder());
    _startMapTimeoutTimer();
    unawaited(_loadDestinationFlagIcon());

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
                Icon(
                  Icons.map_outlined,
                  size: 48,
                  color: context.moto.textTertiary,
                ),
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

    if (_currentLocation == null &&
        (state is NewTravelCheckingPending ||
            state is NewTravelLocationLoading)) {
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
            onMapCreated: _onMapCreated,
            onTap: (_isSelectingDestination || _showPickupConfirmation)
                ? null
                : _handleMapTap,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          Positioned(
            right: 16,
            bottom: (_showDestinationConfirmation || _showPickupConfirmation)
                ? 164
                : 16,
            child: FloatingActionButton(
              heroTag: 'recenter-location',
              mini: true,
              backgroundColor: context.moto.bgBase,
              foregroundColor: context.moto.accent,
              onPressed: _recenterToCurrentLocation,
              child: const Icon(Icons.my_location),
            ),
          ),
          if (_showDestinationConfirmation)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildDestinationConfirmationCard(),
            ),
          if (_showPickupConfirmation)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildPickupConfirmationCard(),
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
          Row(
            children: [
              Expanded(
                child: _buildAddressField(
                  controller: _originController,
                  focusNode: _originFocusNode,
                  hintText: 'Embarque: sua localização atual',
                  icon: Icons.trip_origin,
                  enabled: _pickupSelectionMode == _PickupSelectionMode.address,
                  onTap: () => setState(() => _searchingOrigin = true),
                ),
              ),
              const SizedBox(width: MotoSpace.s2),
              IconButton.filledTonal(
                tooltip: 'Alterar local de embarque',
                onPressed: _showPickupOptions,
                icon: const Icon(Icons.edit_location_alt_outlined),
              ),
            ],
          ),
          const SizedBox(height: MotoSpace.s2),
          Material(
            color: context.moto.bgRaised,
            shape: StadiumBorder(
              side: BorderSide(color: context.moto.borderSubtle),
            ),
            elevation: 6,
            shadowColor: context.moto.shadow,
            clipBehavior: Clip.antiAlias,
            child: TextField(
              controller: _destinationController,
              onTap: () => setState(() => _searchingOrigin = false),
              style: TextStyle(
                fontFamily: MotoFont.ui,
                fontSize: 16,
                color: context.moto.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Pra onde você quer ir?',
                hintStyle: TextStyle(
                  fontFamily: MotoFont.ui,
                  fontSize: 16,
                  color: context.moto.textTertiary,
                ),
                prefixIcon: Icon(Icons.search, color: context.moto.accent),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: MotoSpace.s4,
                  vertical: 18,
                ),
              ),
              onChanged: (query) {
                if (_showDestinationConfirmation) {
                  _clearDestinationPreview(recenter: false, clearText: false);
                }
                _searchDebounceTimer?.cancel();
                final normalizedQuery = query.trim();
                if (normalizedQuery.length < 3) {
                  BlocProvider.of<NewTravelBloc>(
                    context,
                  ).add(SearchPlaces(query: normalizedQuery));
                  return;
                }
                _searchDebounceTimer = Timer(_searchDebounceDuration, () {
                  if (!mounted) return;
                  BlocProvider.of<NewTravelBloc>(
                    context,
                  ).add(SearchPlaces(query: normalizedQuery));
                });
              },
            ),
          ),
          if (!_showDestinationConfirmation &&
              !_showPickupConfirmation &&
              state is NewTravelPlacesLoaded &&
              state.suggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: MotoSpace.s2),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: MotoGlass(
                  painted: true,
                  padding: EdgeInsets.zero,
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: state.suggestions.length,
                    itemBuilder: (_, i) => ListTile(
                      leading: Icon(
                        _searchingOrigin
                            ? Icons.location_on
                            : Icons.flag_outlined,
                        color: context.moto.accent,
                      ),
                      title: Text(
                        _suggestionTitle(state.suggestions[i]),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: _suggestionSubtitle(state.suggestions[i]),
                      onTap: () {
                        final suggestion = state.suggestions[i];
                        if (_searchingOrigin) {
                          _previewOriginSuggestion(suggestion);
                          _originController.text = suggestion.address;
                        } else {
                          _previewDestinationSuggestion(suggestion);
                          _destinationController.text = suggestion.address;
                        }
                      },
                    ),
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
      _originController.text = 'Sua localização atual';
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

  String _suggestionTitle(PlaceSuggestion suggestion) {
    final name = suggestion.name?.trim();
    return name == null || name.isEmpty ? suggestion.address : name;
  }

  Widget? _suggestionSubtitle(PlaceSuggestion suggestion) {
    final name = suggestion.name?.trim();
    if (name == null || name.isEmpty || name == suggestion.address) {
      return null;
    }
    return Text(
      suggestion.address,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    final previewedPosition = _previewedDestination ?? _previewedPickup;
    if (previewedPosition != null) {
      unawaited(
        controller.animateCamera(
          CameraUpdate.newLatLngZoom(previewedPosition, 16),
        ),
      );
    }
  }

  Future<void> _loadDestinationFlagIcon() async {
    const size = 96.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final polePaint = Paint()
      ..color = const Color(0xFF172B4D)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(22, 12), const Offset(22, 84), polePaint);

    final flag = Path()
      ..moveTo(22, 14)
      ..lineTo(78, 25)
      ..lineTo(22, 48)
      ..close();
    canvas.drawPath(flag, Paint()..color = const Color(0xFFE53935));
    canvas.drawPath(
      flag,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(
      const Offset(22, 85),
      6,
      Paint()..color = const Color(0xFF172B4D),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (!mounted || data == null) return;
    setState(() {
      _destinationFlagIcon = BitmapDescriptor.bytes(
        data.buffer.asUint8List(),
        width: 42,
        height: 42,
      );
      final position = _previewedDestination;
      if (position != null) {
        _replaceDestinationMarker(position);
      }
    });
  }

  Marker _destinationMarker(LatLng position) {
    return Marker(
      markerId: const MarkerId('destination'),
      position: position,
      draggable: true,
      onDragEnd: _onDestinationMarkerDragged,
      icon:
          _destinationFlagIcon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      anchor: _destinationFlagIcon == null
          ? const Offset(0.5, 1)
          : const Offset(0.23, 0.92),
      infoWindow: InfoWindow(
        title: 'Destino',
        snippet: _previewedDestinationAddress ?? 'Destino selecionado',
      ),
    );
  }

  void _replaceDestinationMarker(LatLng position) {
    _markers = {
      ..._markers.where(
        (marker) => marker.markerId != const MarkerId('destination'),
      ),
      _destinationMarker(position),
    };
  }

  void _previewDestinationSuggestion(PlaceSuggestion suggestion) {
    final position = LatLng(suggestion.latitude, suggestion.longitude);
    FocusScope.of(context).unfocus();
    setState(() {
      _isSelectingDestination = true;
      _previewedDestination = position;
      _previewedDestinationAddress = suggestion.address;
      _showDestinationConfirmation = true;
      _polylines.clear();
      _replaceDestinationMarker(position);
    });
    unawaited(
      _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(position, 18),
          ) ??
          Future<void>.value(),
    );
    unawaited(_loadDestinationPreview(position));
  }

  void _onDestinationMarkerDragged(LatLng position) {
    setState(() {
      _previewedDestination = position;
      _previewedDestinationAddress = 'Buscando endereço...';
      _destinationController.text = 'Buscando endereço...';
      _polylines.clear();
      _replaceDestinationMarker(position);
    });
    unawaited(
      _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(position, 18),
          ) ??
          Future<void>.value(),
    );
    unawaited(_loadDestinationPreview(position));
  }

  Future<void> _loadDestinationPreview(LatLng position) async {
    final origin = _currentLocation;
    if (origin == null) return;
    final requestId = ++_destinationPreviewRequestId;
    final service = Modular.get<IPlacesAutocompleteService>();

    try {
      final route = await service.getRouteDetails(
        originLat: origin.latitude,
        originLng: origin.longitude,
        destLat: position.latitude,
        destLng: position.longitude,
      );
      if (!mounted || requestId != _destinationPreviewRequestId) return;

      final routePoints = route.encodedPolyline.isEmpty
          ? <LatLng>[origin, position]
          : decodePolyline(route.encodedPolyline);
      // O último ponto devolvido pela rota é o ponto navegável que o Google
      // encaixou na malha viária. Assim, mesmo que o usuário solte a bandeira
      // sobre um prédio ou terreno, ela volta para a rua acessível mais
      // próxima em vez de manter uma coordenada fora da via.
      final snappedDestination = routePoints.isNotEmpty
          ? routePoints.last
          : LatLng(route.destLat, route.destLng);
      setState(() {
        _previewedDestination = snappedDestination;
        _previewedDestinationAddress = route.destinationAddress;
        _destinationController.text = route.destinationAddress;
        _replaceDestinationMarker(snappedDestination);
        _polylines
          ..clear()
          ..add(
            Polyline(
              polylineId: const PolylineId('destination_preview_route'),
              points: routePoints,
              color: const Color(0xFF1F4FE0),
              width: 6,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              jointType: JointType.round,
            ),
          );
      });
      unawaited(
        _mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(snappedDestination, 18),
            ) ??
            Future<void>.value(),
      );
    } catch (_) {
      try {
        final address = await service.getAddressByCoordinates(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        if (!mounted || requestId != _destinationPreviewRequestId) return;
        setState(() {
          _previewedDestinationAddress = address.address;
          _destinationController.text = address.address;
          _replaceDestinationMarker(position);
          _polylines
            ..clear()
            ..add(
              Polyline(
                polylineId: const PolylineId('destination_preview_route'),
                points: [origin, position],
                color: const Color(0xFF1F4FE0),
                width: 6,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
              ),
            );
        });
      } catch (_) {
        if (!mounted || requestId != _destinationPreviewRequestId) return;
        final fallback =
            'Ponto no mapa (${position.latitude.toStringAsFixed(5)}, '
            '${position.longitude.toStringAsFixed(5)})';
        setState(() {
          _previewedDestinationAddress = fallback;
          _destinationController.text = fallback;
          _replaceDestinationMarker(position);
        });
      }
    }
  }

  Widget _buildDestinationConfirmationCard() {
    return MotoGlass(
      painted: true,
      padding: const EdgeInsets.all(MotoSpace.s4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Confirme o local de destino',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: MotoSpace.s1),
          Text(
            'Segure e arraste a bandeira vermelha para ajustar o ponto exato.',
            style: TextStyle(
              color: context.moto.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: MotoSpace.s3),
          Row(
            children: [
              Expanded(
                child: MotoButton(
                  label: 'Cancelar',
                  variant: MotoButtonVariant.glass,
                  large: false,
                  onPressed: _cancelDestinationPreview,
                ),
              ),
              const SizedBox(width: MotoSpace.s3),
              Expanded(
                child: MotoButton(
                  label: 'Confirmar local',
                  large: false,
                  onPressed: _confirmDestinationPreview,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDestinationPreview() {
    final position = _previewedDestination;
    if (position == null) return;
    final suggestion = PlaceSuggestion(
      address: _previewedDestinationAddress ?? _destinationController.text,
      latitude: position.latitude,
      longitude: position.longitude,
    );
    setState(() {
      _showDestinationConfirmation = false;
      _isSelectingDestination = true;
    });
    BlocProvider.of<NewTravelBloc>(context).add(
      SelectPlace(suggestion: suggestion),
    );
  }

  void _cancelDestinationPreview() {
    _clearDestinationPreview(recenter: true, clearText: true);
    BlocProvider.of<NewTravelBloc>(context).add(
      const SearchPlaces(query: ''),
    );
  }

  void _clearDestinationPreview({
    required bool recenter,
    required bool clearText,
  }) {
    _destinationPreviewRequestId++;
    setState(() {
      _showDestinationConfirmation = false;
      _isSelectingDestination = false;
      _previewedDestination = null;
      _previewedDestinationAddress = null;
      _polylines.clear();
      _markers = _markers
          .where(
            (marker) => marker.markerId != const MarkerId('destination'),
          )
          .toSet();
      if (clearText) _destinationController.clear();
    });
    if (recenter) _recenterToCurrentLocation();
  }

  void _previewOriginSuggestion(PlaceSuggestion suggestion) {
    final position = LatLng(suggestion.latitude, suggestion.longitude);
    FocusScope.of(context).unfocus();
    setState(() {
      _searchingOrigin = false;
      _previewedPickup = position;
      _previewedPickupAddress = suggestion.address;
      _showPickupConfirmation = true;
      _polylines.clear();
      _replacePickupPreviewMarker(position);
    });
    BlocProvider.of<NewTravelBloc>(context).add(
      const SearchPlaces(query: ''),
    );
    unawaited(
      _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(position, 18),
          ) ??
          Future<void>.value(),
    );
    unawaited(_loadPickupPreview(position));
  }

  void _replacePickupPreviewMarker(LatLng position) {
    _markers = {
      ..._markers.where(
        (marker) => marker.markerId != const MarkerId('pickup_preview'),
      ),
      Marker(
        markerId: const MarkerId('pickup_preview'),
        position: position,
        draggable: true,
        onDragEnd: _onPickupMarkerDragged,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueGreen,
        ),
        infoWindow: InfoWindow(
          title: 'Embarque',
          snippet: _previewedPickupAddress ?? 'Local de embarque selecionado',
        ),
      ),
    };
  }

  void _onPickupMarkerDragged(LatLng position) {
    setState(() {
      _previewedPickup = position;
      _previewedPickupAddress = 'Buscando endereço...';
      _originController.text = 'Buscando endereço...';
      _replacePickupPreviewMarker(position);
    });
    unawaited(
      _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(position, 18),
          ) ??
          Future<void>.value(),
    );
    unawaited(_loadPickupPreview(position));
  }

  Future<void> _loadPickupPreview(LatLng position) async {
    final referencePosition = _currentLocation;
    if (referencePosition == null) return;
    final requestId = ++_pickupPreviewRequestId;
    final service = Modular.get<IPlacesAutocompleteService>();

    try {
      final route = await service.getRouteDetails(
        originLat: referencePosition.latitude,
        originLng: referencePosition.longitude,
        destLat: position.latitude,
        destLng: position.longitude,
      );
      if (!mounted || requestId != _pickupPreviewRequestId) return;

      final routePoints = route.encodedPolyline.isEmpty
          ? <LatLng>[]
          : decodePolyline(route.encodedPolyline);
      final snappedPickup = routePoints.isNotEmpty
          ? routePoints.last
          : LatLng(route.destLat, route.destLng);
      setState(() {
        _previewedPickup = snappedPickup;
        _previewedPickupAddress = route.destinationAddress;
        _originController.text = route.destinationAddress;
        _replacePickupPreviewMarker(snappedPickup);
      });
      unawaited(
        _mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(snappedPickup, 18),
            ) ??
            Future<void>.value(),
      );
    } catch (_) {
      try {
        final address = await service.getAddressByCoordinates(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        if (!mounted || requestId != _pickupPreviewRequestId) return;
        setState(() {
          _previewedPickupAddress = address.address;
          _originController.text = address.address;
          _replacePickupPreviewMarker(position);
        });
      } catch (_) {
        if (!mounted || requestId != _pickupPreviewRequestId) return;
        final fallback =
            'Ponto no mapa (${position.latitude.toStringAsFixed(5)}, '
            '${position.longitude.toStringAsFixed(5)})';
        setState(() {
          _previewedPickupAddress = fallback;
          _originController.text = fallback;
          _replacePickupPreviewMarker(position);
        });
      }
    }
  }

  Widget _buildPickupConfirmationCard() {
    return MotoGlass(
      painted: true,
      padding: const EdgeInsets.all(MotoSpace.s4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Confirme o local de embarque',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: MotoSpace.s1),
          Text(
            'Segure e arraste o marcador verde para ajustar o ponto exato.',
            style: TextStyle(
              color: context.moto.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: MotoSpace.s3),
          Row(
            children: [
              Expanded(
                child: MotoButton(
                  label: 'Cancelar',
                  variant: MotoButtonVariant.glass,
                  large: false,
                  onPressed: _cancelPickupPreview,
                ),
              ),
              const SizedBox(width: MotoSpace.s3),
              Expanded(
                child: MotoButton(
                  label: 'Confirmar local',
                  large: false,
                  onPressed: _confirmPickupPreview,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmPickupPreview() {
    final position = _previewedPickup;
    if (position == null) return;
    final suggestion = PlaceSuggestion(
      address: _previewedPickupAddress ?? _originController.text,
      latitude: position.latitude,
      longitude: position.longitude,
    );
    _pickupPreviewRequestId++;
    setState(() => _showPickupConfirmation = false);
    BlocProvider.of<NewTravelBloc>(context).add(
      SelectOriginPlace(suggestion: suggestion),
    );
  }

  void _cancelPickupPreview() {
    _clearPickupPreview(recenter: true, clearText: true, refocus: true);
    BlocProvider.of<NewTravelBloc>(context).add(
      const SearchPlaces(query: ''),
    );
  }

  void _clearPickupPreview({
    required bool recenter,
    required bool clearText,
    required bool refocus,
  }) {
    _pickupPreviewRequestId++;
    setState(() {
      _showPickupConfirmation = false;
      _previewedPickup = null;
      _previewedPickupAddress = null;
      _searchingOrigin = true;
      _markers = _markers
          .where(
            (marker) => marker.markerId != const MarkerId('pickup_preview'),
          )
          .toSet();
      if (clearText) _originController.clear();
    });
    if (recenter) _recenterToCurrentLocation();
    if (refocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _originFocusNode.requestFocus();
      });
    }
  }

  void _onOriginSelected(LatLng position, String address) {
    if (!mounted) return;
    _pickupPreviewRequestId++;
    setState(() {
      _currentLocation = position;
      _searchingOrigin = false;
      _pickupSelectionMode = _PickupSelectionMode.destination;
      _previewedPickup = null;
      _previewedPickupAddress = null;
      _showPickupConfirmation = false;
      _originController.text = address;
      _markers = {
        Marker(
          markerId: const MarkerId('pickup_location'),
          position: position,
          infoWindow: const InfoWindow(title: 'Local de embarque'),
        ),
      };
    });
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(position, 15));
  }

  Widget _buildAddressField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: context.moto.bgRaised,
      shape: StadiumBorder(side: BorderSide(color: context.moto.borderSubtle)),
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        onTap: onTap,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(icon, color: context.moto.accent),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: MotoSpace.s4,
            vertical: 14,
          ),
        ),
        onChanged: (query) {
          if (_showPickupConfirmation) {
            _clearPickupPreview(
              recenter: false,
              clearText: false,
              refocus: false,
            );
          }
          _searchingOrigin = true;
          _dispatchPlaceSearch(query);
        },
      ),
    );
  }

  Future<void> _showPickupOptions() async {
    FocusScope.of(context).unfocus();
    final option = await showModalBottomSheet<_PickupSelectionMode>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: MotoSpace.s3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('Alterar local de embarque'),
                subtitle: Text(
                  'Se não alterar, usaremos sua localização atual.',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Digitar endereço'),
                onTap: () => Navigator.of(ctx).pop(
                  _PickupSelectionMode.address,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.map_outlined),
                title: const Text('Selecionar no mapa'),
                onTap: () => Navigator.of(ctx).pop(_PickupSelectionMode.map),
              ),
              ListTile(
                leading: const Icon(Icons.my_location),
                title: const Text('Usar minha localização atual'),
                onTap: () => Navigator.of(ctx).pop(
                  _PickupSelectionMode.destination,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || option == null) return;

    setState(() {
      _pickupSelectionMode = option;
      _searchingOrigin = option == _PickupSelectionMode.address;
    });

    switch (option) {
      case _PickupSelectionMode.address:
        _originController.clear();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _originFocusNode.requestFocus();
        });
      case _PickupSelectionMode.map:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Toque no mapa para marcar o local de embarque.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      case _PickupSelectionMode.destination:
        _originController.text = 'Sua localização atual';
        BlocProvider.of<NewTravelBloc>(context).add(const GetCurrentLocation());
    }
  }

  Future<void> _handleMapTap(LatLng latLng) async {
    if (_pickupSelectionMode == _PickupSelectionMode.map) {
      if (_isConfirmingPickup) return;
      setState(() => _isConfirmingPickup = true);
      final confirmed = await _confirmPickup(
        'Usar este ponto como local de embarque?',
        'O ponto selecionado no mapa será usado para o motorista encontrar você.',
      );
      if (!mounted) return;
      setState(() => _isConfirmingPickup = false);
      if (!confirmed) return;
      BlocProvider.of<NewTravelBloc>(context).add(
        SetOriginOnMap(
          latitude: latLng.latitude,
          longitude: latLng.longitude,
        ),
      );
      return;
    }

    const mapDestinationLabel = 'Buscando endereço...';
    _previewDestinationSuggestion(
      PlaceSuggestion(
        address: mapDestinationLabel,
        latitude: latLng.latitude,
        longitude: latLng.longitude,
      ),
    );
  }

  Future<bool> _confirmPickup(String title, String description) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(description),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Voltar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Confirmar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _dispatchPlaceSearch(String query) {
    _searchDebounceTimer?.cancel();
    final normalizedQuery = query.trim();
    if (normalizedQuery.length < 3) {
      BlocProvider.of<NewTravelBloc>(
        context,
      ).add(SearchPlaces(query: normalizedQuery));
      return;
    }
    _searchDebounceTimer = Timer(_searchDebounceDuration, () {
      if (!mounted) return;
      BlocProvider.of<NewTravelBloc>(
        context,
      ).add(SearchPlaces(query: normalizedQuery));
    });
  }

  Future<void> _showLocationErrorDialog(
    String message,
    LocationStatus status,
  ) async {
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
                  BlocProvider.of<NewTravelBloc>(
                    context,
                  ).add(const GetCurrentLocation());
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
                BlocProvider.of<NewTravelBloc>(
                  context,
                ).add(const GetCurrentLocation());
              },
              child: const Text('Tentar novamente'),
            ),
        ],
      ),
    );
  }

  void _showRouteBottomSheet(TravelRouteEntity route) {
    final distKm = (route.distanceMeters / 1000).toStringAsFixed(1);
    _isRouteBottomSheetOpen = true;

    final closed = showModalBottomSheet<void>(
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
    );
    _routeBottomSheetClosed = closed;
    closed.whenComplete(() {
      if (mounted) {
        setState(() {
          _isRouteBottomSheetOpen = false;
          _isSelectingDestination = false;
        });
      }
    });
  }

  Future<void> _handleNoDriversAvailable(String message) async {
    // `canPop` também é true para a própria página. Fechamos somente o
    // resumo, esperamos a rota modal encerrar e só então apresentamos o
    // diálogo. Isso evita que a animação de fechamento descarte o modal novo.
    if (_isRouteBottomSheetOpen) {
      Navigator.of(context).pop();
      await _routeBottomSheetClosed;
    }
    if (mounted) await _showNoDriversDialog(message);
  }

  Future<void> _showNoDriversDialog(String message) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Nenhum motorista foi encontrado'),
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
                  style: TextStyle(
                    color: context.moto.textOnAccent,
                    fontSize: 16,
                  ),
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
                  style: TextStyle(
                    color: context.moto.textPrimary,
                    fontSize: 16,
                  ),
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
  State<_RouteBottomSheetContent> createState() =>
      _RouteBottomSheetContentState();
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
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Resumo da viagem',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: MotoSpace.s4),
                        MotoRoute(
                          from: (widget.route.departureAddress, 'Embarque'),
                          to: (widget.route.destinationAddress, 'Destino'),
                        ),
                        const SizedBox(height: MotoSpace.s4),
                        MotoMetrics(
                          items: [
                            (widget.distKm, 'km', 'Distância'),
                            (
                              _formatTravelTime(widget.route.timeMinutes),
                              '',
                              'Duração',
                            ),
                          ],
                        ),
                        Visibility(
                          visible: widget.hasPriorityAccess,
                          child: Row(
                            spacing: 16,
                            children: [
                              Switch(
                                value: widget.orderType == OrderType.priority,
                                onChanged: (value) {
                                  widget.orderType =
                                      widget.orderType == OrderType.normal
                                      ? OrderType.priority
                                      : OrderType.normal;
                                  setState(() {});
                                },
                              ),
                              Expanded(
                                child: Text(
                                  'Pedido com prioridade',
                                  style: TextStyle(
                                    color: context.moto.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: MotoSpace.s3),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stackActions =
                        constraints.maxWidth < 320 ||
                        MediaQuery.textScalerOf(context).scale(14) > 17;
                    final cancelButton = MotoButton(
                      label: 'Cancelar',
                      variant: MotoButtonVariant.glass,
                      onPressed: isCreating ? null : Modular.to.pop,
                    );
                    final requestButton = MotoButton(
                      label: 'Solicitar viagem',
                      loading: isCreating,
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
                    );

                    if (stackActions) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          requestButton,
                          const SizedBox(height: MotoSpace.s2),
                          cancelButton,
                        ],
                      );
                    }

                    return Row(
                      spacing: MotoSpace.s4,
                      children: [
                        Expanded(child: cancelButton),
                        Expanded(flex: 2, child: requestButton),
                      ],
                    );
                  },
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
