// PSG-07: NewTravelBloc não tinha nenhum teste — exatamente onde o bug do
// mapa (PSG-01, spinner infinito quando o GPS demora) e o fluxo de
// solicitação de corrida vivem. Cobre o bloc isoladamente (sem UI), usando
// mocktail para os colaboradores (LocationService, NewTravelRepository,
// IPlacesAutocompleteService, SignalRService, AuthStorage).
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_passenger/core/auth/auth_storage.dart';
import 'package:moto_passenger/core/location/location_service.dart';
import 'package:moto_passenger/core/maps/i_places_autocomplete_service.dart';
import 'package:moto_passenger/core/network/signalr_service.dart';
import 'package:moto_passenger/modules/new_travel/data/datasources/new_travel_datasource.dart';
import 'package:moto_passenger/modules/new_travel/data/repositories/new_travel_repository.dart';
import 'package:moto_passenger/modules/new_travel/presentation/blocs/new_travel_bloc.dart';
import 'package:moto_passenger/modules/new_travel/presentation/blocs/new_travel_event.dart';
import 'package:moto_passenger/modules/new_travel/presentation/blocs/new_travel_state.dart';
import 'package:moto_passenger/modules/new_travel/presentation/pages/new_travel_page.dart';

class MockNewTravelRepository extends Mock implements NewTravelRepository {}

class MockLocationService extends Mock implements LocationService {}

class MockPlacesAutocompleteService extends Mock implements IPlacesAutocompleteService {}

class MockSignalRService extends Mock implements SignalRService {}

class MockAuthStorage extends Mock implements AuthStorage {}

Position _fakePosition({double lat = -23.2, double lng = -45.9}) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime(2026, 1, 1),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  late MockNewTravelRepository repository;
  late MockLocationService locationService;
  late MockPlacesAutocompleteService placesService;
  late MockSignalRService signalR;
  late MockAuthStorage authStorage;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    repository = MockNewTravelRepository();
    locationService = MockLocationService();
    placesService = MockPlacesAutocompleteService();
    signalR = MockSignalRService();
    authStorage = MockAuthStorage();

    // Fluxo de sinalização do pedido (_ensureTravelOrdersConnected) é
    // "best effort" e não afeta os estados emitidos — deixado neutro.
    when(() => authStorage.getToken()).thenAnswer((_) async => 'token-123');
    when(() => signalR.connect(any(), any(), any())).thenAnswer((_) async {});
  });

  NewTravelBloc buildBloc() => NewTravelBloc(repository, locationService, placesService, signalR, authStorage);

  group('GetCurrentLocation', () {
    blocTest<NewTravelBloc, NewTravelState>(
      'emite Loading e depois Loaded quando a localização é concedida',
      build: () {
        when(() => locationService.getCurrentPosition()).thenAnswer(
          (_) async => LocationResult(position: _fakePosition(), status: LocationStatus.granted),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const GetCurrentLocation()),
      expect: () => [
        const NewTravelLocationLoading(),
        isA<NewTravelLocationLoaded>()
            .having((s) => s.position, 'position', const LatLng(-23.2, -45.9)),
      ],
    );

    blocTest<NewTravelBloc, NewTravelState>(
      // PSG-01: o timeout de location_service.dart agora devolve um status
      // explícito em vez de nunca resolver — o bloc precisa transformar isso
      // numa mensagem clara com opção de tentar de novo, não travar a UI.
      'PSG-01: emite erro com mensagem de GPS quando o status é timeout',
      build: () {
        when(() => locationService.getCurrentPosition())
            .thenAnswer((_) async => const LocationResult(status: LocationStatus.timeout));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const GetCurrentLocation()),
      expect: () => [
        const NewTravelLocationLoading(),
        isA<NewTravelLocationError>()
            .having((s) => s.status, 'status', LocationStatus.timeout)
            .having((s) => s.message, 'message', contains('GPS')),
      ],
    );

    blocTest<NewTravelBloc, NewTravelState>(
      'emite erro com mensagem de serviço desativado quando o GPS está desligado',
      build: () {
        when(() => locationService.getCurrentPosition())
            .thenAnswer((_) async => const LocationResult(status: LocationStatus.serviceDisabled));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const GetCurrentLocation()),
      expect: () => [
        const NewTravelLocationLoading(),
        isA<NewTravelLocationError>().having((s) => s.status, 'status', LocationStatus.serviceDisabled),
      ],
    );

    blocTest<NewTravelBloc, NewTravelState>(
      'emite erro quando LocationService lança exceção',
      build: () {
        when(() => locationService.getCurrentPosition()).thenThrow(Exception('boom'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const GetCurrentLocation()),
      expect: () => [
        const NewTravelLocationLoading(),
        isA<NewTravelLocationError>(),
      ],
    );
  });

  group('CheckPendingOrder', () {
    blocTest<NewTravelBloc, NewTravelState>(
      'sem pedido pendente, prossegue para buscar localização',
      build: () {
        when(() => repository.getLatestOrder()).thenAnswer((_) async => null);
        when(() => locationService.getCurrentPosition()).thenAnswer(
          (_) async => LocationResult(position: _fakePosition(), status: LocationStatus.granted),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const CheckPendingOrder()),
      expect: () => [
        const NewTravelCheckingPending(),
        const NewTravelLocationLoading(),
        isA<NewTravelLocationLoaded>(),
      ],
    );

    blocTest<NewTravelBloc, NewTravelState>(
      'pedido Pending emite NewTravelPendingOrder',
      build: () {
        when(() => repository.getLatestOrder()).thenAnswer((_) async => {
              'status': 'Pending',
              'orderId': 'order-1',
              'travelId': '',
              'createdAt': '2026-01-01T10:00:00Z',
              'destinationAddress': 'Rua X, 100',
            });
        return buildBloc();
      },
      act: (bloc) => bloc.add(const CheckPendingOrder()),
      expect: () => [
        const NewTravelCheckingPending(),
        isA<NewTravelPendingOrder>()
            .having((s) => s.orderId, 'orderId', 'order-1')
            .having((s) => s.destinationAddress, 'destinationAddress', 'Rua X, 100'),
      ],
    );

    blocTest<NewTravelBloc, NewTravelState>(
      'viagem Accepted/InProgress com travelId emite NewTravelActiveOrder',
      build: () {
        when(() => repository.getLatestOrder()).thenAnswer((_) async => {
              'status': 'InProgress',
              'orderId': 'order-1',
              'travelId': 'travel-1',
            });
        return buildBloc();
      },
      act: (bloc) => bloc.add(const CheckPendingOrder()),
      expect: () => [
        const NewTravelCheckingPending(),
        isA<NewTravelActiveOrder>()
            .having((s) => s.travelId, 'travelId', 'travel-1')
            .having((s) => s.status, 'status', 'InProgress'),
      ],
    );

    blocTest<NewTravelBloc, NewTravelState>(
      'erro de rede ao checar pedido pendente não trava o fluxo — prossegue para localização',
      build: () {
        when(() => repository.getLatestOrder()).thenThrow(Exception('network down'));
        when(() => locationService.getCurrentPosition()).thenAnswer(
          (_) async => LocationResult(position: _fakePosition(), status: LocationStatus.granted),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const CheckPendingOrder()),
      expect: () => [
        const NewTravelCheckingPending(),
        const NewTravelLocationLoading(),
        isA<NewTravelLocationLoaded>(),
      ],
    );
  });

  group('ConfirmTravel', () {
    blocTest<NewTravelBloc, NewTravelState>(
      'cria o pedido normal com sucesso',
      build: () {
        when(() => repository.createOrder(any())).thenAnswer((_) async => {'orderId': 'order-99'});
        return buildBloc();
      },
      act: (bloc) => bloc.add(const ConfirmTravel(
        originLat: -23.2,
        originLng: -45.9,
        destinationLat: -23.3,
        destinationLng: -46.0,
        orderType: OrderType.normal,
      )),
      expect: () => [
        const NewTravelCreating(),
        isA<NewTravelCreated>().having((s) => s.orderId, 'orderId', 'order-99'),
      ],
      verify: (_) {
        verify(() => repository.createOrder(any())).called(1);
        verifyNever(() => repository.createPriorityOrder(any()));
      },
    );

    blocTest<NewTravelBloc, NewTravelState>(
      'cria o pedido prioritário quando orderType é priority',
      build: () {
        when(() => repository.createPriorityOrder(any())).thenAnswer((_) async => {'orderId': 'order-100'});
        return buildBloc();
      },
      act: (bloc) => bloc.add(const ConfirmTravel(
        originLat: -23.2,
        originLng: -45.9,
        destinationLat: -23.3,
        destinationLng: -46.0,
        orderType: OrderType.priority,
      )),
      expect: () => [
        const NewTravelCreating(),
        isA<NewTravelCreated>(),
      ],
      verify: (_) {
        verify(() => repository.createPriorityOrder(any())).called(1);
      },
    );

    blocTest<NewTravelBloc, NewTravelState>(
      'sem motoristas disponíveis emite NewTravelNoDriversAvailable',
      build: () {
        when(() => repository.createOrder(any())).thenThrow(
          const NoDriversAvailableException(partitionAcronym: 'JAC', message: 'Nenhum motorista disponível.'),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const ConfirmTravel(
        originLat: -23.2,
        originLng: -45.9,
        destinationLat: -23.3,
        destinationLng: -46.0,
        orderType: OrderType.normal,
      )),
      expect: () => [
        const NewTravelCreating(),
        isA<NewTravelNoDriversAvailable>()
            .having((s) => s.partitionAcronym, 'partitionAcronym', 'JAC'),
      ],
    );

    blocTest<NewTravelBloc, NewTravelState>(
      'falha genérica emite NewTravelFailure',
      build: () {
        when(() => repository.createOrder(any())).thenThrow(Exception('server error'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const ConfirmTravel(
        originLat: -23.2,
        originLng: -45.9,
        destinationLat: -23.3,
        destinationLng: -46.0,
        orderType: OrderType.normal,
      )),
      expect: () => [
        const NewTravelCreating(),
        isA<NewTravelFailure>(),
      ],
    );
  });

  group('CancelPendingOrder', () {
    blocTest<NewTravelBloc, NewTravelState>(
      'cancela o pedido e prossegue para buscar localização',
      build: () {
        when(() => repository.cancelOrder(any())).thenAnswer((_) async {});
        when(() => locationService.getCurrentPosition()).thenAnswer(
          (_) async => LocationResult(position: _fakePosition(), status: LocationStatus.granted),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const CancelPendingOrder(orderId: 'order-1')),
      expect: () => [
        const NewTravelLocationLoading(),
        isA<NewTravelLocationLoaded>(),
      ],
      verify: (_) {
        verify(() => repository.cancelOrder('order-1')).called(1);
      },
    );

    blocTest<NewTravelBloc, NewTravelState>(
      'mesmo se cancelar falhar, deixa o usuário prosseguir',
      build: () {
        when(() => repository.cancelOrder(any())).thenThrow(Exception('boom'));
        when(() => locationService.getCurrentPosition()).thenAnswer(
          (_) async => LocationResult(position: _fakePosition(), status: LocationStatus.granted),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const CancelPendingOrder(orderId: 'order-1')),
      expect: () => [
        const NewTravelLocationLoading(),
        isA<NewTravelLocationLoaded>(),
      ],
    );
  });
}
