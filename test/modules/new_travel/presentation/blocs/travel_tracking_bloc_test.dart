// PSG-07: TravelTrackingBloc não tinha nenhum teste — é o bloc com a lógica
// mais complexa do fluxo de corrida (polling com backoff, deduplicação de
// eventos SignalR, guarda contra regressão de estado). Cobre exatamente os
// comportamentos documentados nos comentários do próprio bloc.
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_passenger/modules/new_travel/data/repositories/travel_tracking_repository.dart';
import 'package:moto_passenger/modules/new_travel/domain/entities/travel_tracking_entity.dart';
import 'package:moto_passenger/modules/new_travel/presentation/blocs/travel_tracking_bloc.dart';
import 'package:moto_passenger/modules/new_travel/presentation/blocs/travel_tracking_event.dart';
import 'package:moto_passenger/modules/new_travel/presentation/blocs/travel_tracking_state.dart';

class MockTravelTrackingRepository extends Mock implements ITravelTrackingRepository {}

const _driver = DriverInfoEntity(driverId: 'driver-1', fullName: 'João Motorista');

TravelTrackingEntity _travel({
  required TravelStatus status,
  String travelId = 'travel-1',
  String? driverId,
}) =>
    TravelTrackingEntity(
      travelId: travelId,
      orderId: 'order-1',
      status: status,
      createdAt: DateTime(2026, 1, 1),
      driverId: driverId,
    );

void main() {
  late MockTravelTrackingRepository repository;

  setUp(() {
    repository = MockTravelTrackingRepository();
  });

  TravelTrackingBloc buildBloc() => TravelTrackingBloc(repository);

  group('LoadTravel', () {
    blocTest<TravelTrackingBloc, TravelTrackingState>(
      'status Pending emite TravelTrackingPending',
      build: () {
        when(() => repository.getTravel('travel-1'))
            .thenAnswer((_) async => _travel(status: TravelStatus.pending));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const LoadTravel('travel-1')),
      expect: () => [
        const TravelTrackingLoading(),
        isA<TravelTrackingPending>().having((s) => s.travelId, 'travelId', 'travel-1'),
      ],
    );

    blocTest<TravelTrackingBloc, TravelTrackingState>(
      'status Accepted resolve o motorista e emite TravelTrackingAccepted',
      build: () {
        when(() => repository.getTravel('travel-1'))
            .thenAnswer((_) async => _travel(status: TravelStatus.accepted, driverId: 'driver-1'));
        when(() => repository.getDriverProfile('driver-1')).thenAnswer((_) async => _driver);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const LoadTravel('travel-1')),
      expect: () => [
        const TravelTrackingLoading(),
        isA<TravelTrackingAccepted>()
            .having((s) => s.driver?.fullName, 'driver.fullName', 'João Motorista'),
      ],
    );

    blocTest<TravelTrackingBloc, TravelTrackingState>(
      'erro ao carregar emite TravelTrackingFailure',
      build: () {
        when(() => repository.getTravel('travel-1')).thenThrow(Exception('network error'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const LoadTravel('travel-1')),
      expect: () => [
        const TravelTrackingLoading(),
        isA<TravelTrackingFailure>(),
      ],
    );

    blocTest<TravelTrackingBloc, TravelTrackingState>(
      'falha ao resolver o motorista não impede o estado Accepted (driver fica nulo)',
      build: () {
        when(() => repository.getTravel('travel-1'))
            .thenAnswer((_) async => _travel(status: TravelStatus.accepted, driverId: 'driver-1'));
        when(() => repository.getDriverProfile('driver-1')).thenThrow(Exception('boom'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const LoadTravel('travel-1')),
      expect: () => [
        const TravelTrackingLoading(),
        isA<TravelTrackingAccepted>().having((s) => s.driver, 'driver', isNull),
      ],
    );
  });

  group('Guarda contra regressão de estado (_updateStateFromTravel)', () {
    blocTest<TravelTrackingBloc, TravelTrackingState>(
      'já em InProgress, um poll que traz Accepted (resposta atrasada) é ignorado',
      build: () {
        when(() => repository.getTravel('travel-1'))
            .thenAnswer((_) async => _travel(status: TravelStatus.accepted, driverId: 'driver-1'));
        return buildBloc();
      },
      seed: () => const TravelTrackingInProgress(travelId: 'travel-1'),
      act: (bloc) => bloc.add(const PollTravelStatus('travel-1')),
      expect: () => <TravelTrackingState>[],
    );

    blocTest<TravelTrackingBloc, TravelTrackingState>(
      'já em InProgress, um poll que traz Pending (resposta atrasada) é ignorado',
      build: () {
        when(() => repository.getTravel('travel-1'))
            .thenAnswer((_) async => _travel(status: TravelStatus.pending));
        return buildBloc();
      },
      seed: () => const TravelTrackingInProgress(travelId: 'travel-1'),
      act: (bloc) => bloc.add(const PollTravelStatus('travel-1')),
      expect: () => <TravelTrackingState>[],
    );

    blocTest<TravelTrackingBloc, TravelTrackingState>(
      'já em Completed (estado terminal), qualquer poll subsequente é ignorado',
      build: () {
        when(() => repository.getTravel('travel-1'))
            .thenAnswer((_) async => _travel(status: TravelStatus.inProgress, driverId: 'driver-1'));
        return buildBloc();
      },
      seed: () => const TravelTrackingCompleted(travelId: 'travel-1'),
      act: (bloc) => bloc.add(const PollTravelStatus('travel-1')),
      expect: () => <TravelTrackingState>[],
    );

    blocTest<TravelTrackingBloc, TravelTrackingState>(
      'poll bem-sucedido com status terminal para o polling (Completed)',
      build: () {
        when(() => repository.getTravel('travel-1'))
            .thenAnswer((_) async => _travel(status: TravelStatus.completed));
        return buildBloc();
      },
      seed: () => const TravelTrackingInProgress(travelId: 'travel-1'),
      act: (bloc) => bloc.add(const PollTravelStatus('travel-1')),
      expect: () => [isA<TravelTrackingCompleted>()],
    );
  });

  group('Eventos de SignalR (dedup)', () {
    blocTest<TravelTrackingBloc, TravelTrackingState>(
      'TravelOrderAccepted fora do estado Pending é ignorado (evento duplicado/atrasado)',
      build: () {
        when(() => repository.getDriverProfile(any())).thenAnswer((_) async => _driver);
        return buildBloc();
      },
      seed: () => const TravelTrackingAccepted(travelId: 'travel-1', driver: _driver),
      act: (bloc) => bloc.add(const TravelOrderAccepted({'travelId': 'travel-1', 'driverId': 'driver-2'})),
      expect: () => <TravelTrackingState>[],
      verify: (_) {
        verifyNever(() => repository.getDriverProfile(any()));
      },
    );

    blocTest<TravelTrackingBloc, TravelTrackingState>(
      'TravelOrderAccepted a partir de Pending emite Accepted com o motorista resolvido',
      build: () {
        when(() => repository.getDriverProfile('driver-1')).thenAnswer((_) async => _driver);
        return buildBloc();
      },
      seed: () => const TravelTrackingPending(travelId: 'travel-1', orderId: 'order-1'),
      act: (bloc) => bloc.add(const TravelOrderAccepted({'travelId': 'travel-1', 'driverId': 'driver-1'})),
      expect: () => [
        isA<TravelTrackingAccepted>().having((s) => s.driver?.driverId, 'driver.driverId', 'driver-1'),
      ],
    );

    blocTest<TravelTrackingBloc, TravelTrackingState>(
      'TravelStarted a partir de Accepted preserva motorista e coordenadas ao virar InProgress',
      build: () => buildBloc(),
      seed: () => const TravelTrackingAccepted(
        travelId: 'travel-1',
        driver: _driver,
        driverLatitude: -23.1,
        driverLongitude: -45.8,
        destinationLatitude: -23.3,
        destinationLongitude: -46.0,
      ),
      act: (bloc) => bloc.add(const TravelStarted({'travelId': 'travel-1'})),
      expect: () => [
        isA<TravelTrackingInProgress>()
            .having((s) => s.driver?.driverId, 'driver.driverId', 'driver-1')
            .having((s) => s.driverLatitude, 'driverLatitude', -23.1)
            .having((s) => s.destinationLatitude, 'destinationLatitude', -23.3),
      ],
    );

    blocTest<TravelTrackingBloc, TravelTrackingState>(
      'DriverLocationUpdated atualiza lat/lng preservando o resto do estado Accepted',
      build: () => buildBloc(),
      seed: () => const TravelTrackingAccepted(travelId: 'travel-1', driver: _driver),
      act: (bloc) => bloc.add(const DriverLocationUpdated({'latitude': -23.5, 'longitude': -46.6})),
      expect: () => [
        isA<TravelTrackingAccepted>()
            .having((s) => s.driverLatitude, 'driverLatitude', -23.5)
            .having((s) => s.driverLongitude, 'driverLongitude', -46.6)
            .having((s) => s.driver?.driverId, 'driver.driverId', 'driver-1'),
      ],
    );

    blocTest<TravelTrackingBloc, TravelTrackingState>(
      'DriverLocationUpdated fora de Accepted/InProgress é ignorado',
      build: () => buildBloc(),
      seed: () => const TravelTrackingPending(travelId: 'travel-1', orderId: 'order-1'),
      act: (bloc) => bloc.add(const DriverLocationUpdated({'latitude': -23.5, 'longitude': -46.6})),
      expect: () => <TravelTrackingState>[],
    );

    blocTest<TravelTrackingBloc, TravelTrackingState>(
      'TravelCancelled emite TravelTrackingCancelled com o motivo',
      build: () => buildBloc(),
      seed: () => const TravelTrackingAccepted(travelId: 'travel-1', driver: _driver),
      act: (bloc) => bloc.add(const TravelCancelled({'travelId': 'travel-1', 'reason': 'Motorista indisponível'})),
      expect: () => [
        isA<TravelTrackingCancelled>().having((s) => s.reason, 'reason', 'Motorista indisponível'),
      ],
    );
  });

  group('CancelTravel', () {
    blocTest<TravelTrackingBloc, TravelTrackingState>(
      'sucesso emite TravelTrackingCancelled',
      build: () {
        when(() => repository.cancelTravel(any())).thenAnswer((_) async {});
        return buildBloc();
      },
      act: (bloc) => bloc.add(const CancelTravel('travel-1')),
      expect: () => [
        isA<TravelTrackingCancelled>().having((s) => s.reason, 'reason', 'Cancelada pelo passageiro'),
      ],
    );

    blocTest<TravelTrackingBloc, TravelTrackingState>(
      'falha ao cancelar emite TravelTrackingFailure',
      build: () {
        when(() => repository.cancelTravel(any())).thenThrow(Exception('boom'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const CancelTravel('travel-1')),
      expect: () => [isA<TravelTrackingFailure>()],
    );
  });
}
