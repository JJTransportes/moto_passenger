// Spec pickup-arrival-alerts (req 4.x): o card do passageiro mostra "motorista
// próximo" e "motorista chegou", reidrata pelo campo pickupProximity da viagem
// e limpa a indicação quando a viagem inicia ou é cancelada.
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

TravelTrackingEntity _accepted({PickupProximity pickupProximity = PickupProximity.none}) =>
    TravelTrackingEntity(
      travelId: 'travel-1',
      orderId: 'order-1',
      status: TravelStatus.accepted,
      createdAt: DateTime(2026, 1, 1),
      driverId: 'driver-1',
      driver: _driver,
      pickupProximity: pickupProximity,
    );

Map<String, dynamic> _alert(String kind, {String travelId = 'travel-1'}) => {
      'travelId': travelId,
      'kind': kind,
      'occurredAt': '2026-10-02T15:00:00Z',
    };

TravelTrackingAccepted _acceptedState({PickupProximity pickupProximity = PickupProximity.none}) =>
    TravelTrackingAccepted(
      travelId: 'travel-1',
      driver: _driver,
      driverLatitude: -23.3,
      driverLongitude: -45.9,
      pickupProximity: pickupProximity,
    );

void main() {
  late MockTravelTrackingRepository repository;

  setUp(() {
    repository = MockTravelTrackingRepository();
  });

  TravelTrackingBloc buildBloc() => TravelTrackingBloc(repository);

  group('PickupProximity.parse', () {
    test('converte os valores do backend e cai em none para o resto', () {
      expect(PickupProximity.parse('Nearby'), PickupProximity.nearby);
      expect(PickupProximity.parse('Arrived'), PickupProximity.arrived);
      expect(PickupProximity.parse('None'), PickupProximity.none);
      expect(PickupProximity.parse(null), PickupProximity.none);
      expect(PickupProximity.parse('qualquer'), PickupProximity.none);
    });
  });

  group('DriverProximityAlerted', () {
    blocTest<TravelTrackingBloc, TravelTrackingState>(
      'Nearby em Accepted emite o estado com pickupProximity nearby',
      build: buildBloc,
      seed: () => _acceptedState(),
      act: (bloc) => bloc.add(DriverProximityAlerted(_alert('Nearby'))),
      expect: () => [
        isA<TravelTrackingAccepted>()
            .having((s) => s.pickupProximity, 'pickupProximity', PickupProximity.nearby)
            .having((s) => s.driver, 'driver preservado', _driver)
            .having((s) => s.driverLatitude, 'posição preservada', -23.3),
      ],
    );

    blocTest<TravelTrackingBloc, TravelTrackingState>(
      'Arrived substitui nearby',
      build: buildBloc,
      seed: () => _acceptedState(pickupProximity: PickupProximity.nearby),
      act: (bloc) => bloc.add(DriverProximityAlerted(_alert('Arrived'))),
      expect: () => [
        isA<TravelTrackingAccepted>()
            .having((s) => s.pickupProximity, 'pickupProximity', PickupProximity.arrived),
      ],
    );

    blocTest<TravelTrackingBloc, TravelTrackingState>(
      'Nearby atrasado depois de Arrived não regride o card',
      build: buildBloc,
      seed: () => _acceptedState(pickupProximity: PickupProximity.arrived),
      act: (bloc) => bloc.add(DriverProximityAlerted(_alert('Nearby'))),
      expect: () => <TravelTrackingState>[],
    );

    blocTest<TravelTrackingBloc, TravelTrackingState>(
      'evento repetido não reemite estado',
      build: buildBloc,
      seed: () => _acceptedState(pickupProximity: PickupProximity.nearby),
      act: (bloc) => bloc.add(DriverProximityAlerted(_alert('Nearby'))),
      expect: () => <TravelTrackingState>[],
    );

    blocTest<TravelTrackingBloc, TravelTrackingState>(
      'evento de outra viagem é ignorado',
      build: buildBloc,
      seed: () => _acceptedState(),
      act: (bloc) => bloc.add(DriverProximityAlerted(_alert('Arrived', travelId: 'outra'))),
      expect: () => <TravelTrackingState>[],
    );

    blocTest<TravelTrackingBloc, TravelTrackingState>(
      'tipo desconhecido é ignorado',
      build: buildBloc,
      seed: () => _acceptedState(),
      act: (bloc) => bloc.add(DriverProximityAlerted(_alert('Banana'))),
      expect: () => <TravelTrackingState>[],
    );

    blocTest<TravelTrackingBloc, TravelTrackingState>(
      'fora de Accepted (InProgress) o alerta é ignorado',
      build: buildBloc,
      seed: () => const TravelTrackingInProgress(travelId: 'travel-1', driver: _driver),
      act: (bloc) => bloc.add(DriverProximityAlerted(_alert('Arrived'))),
      expect: () => <TravelTrackingState>[],
    );

    blocTest<TravelTrackingBloc, TravelTrackingState>(
      'atualização de localização preserva o pickupProximity',
      build: buildBloc,
      seed: () => _acceptedState(pickupProximity: PickupProximity.arrived),
      act: (bloc) => bloc.add(const DriverLocationUpdated({'latitude': -23.31, 'longitude': -45.91})),
      expect: () => [
        isA<TravelTrackingAccepted>()
            .having((s) => s.pickupProximity, 'pickupProximity', PickupProximity.arrived)
            .having((s) => s.driverLatitude, 'driverLatitude', -23.31),
      ],
    );

    blocTest<TravelTrackingBloc, TravelTrackingState>(
      'atualização de distância preserva o pickupProximity',
      build: buildBloc,
      seed: () => _acceptedState(pickupProximity: PickupProximity.nearby),
      act: (bloc) => bloc.add(const DistanceUpdated({
        'distanceToDestinationInMeters': 1200,
        'remainingTimeEstimate': 4,
      })),
      expect: () => [
        isA<TravelTrackingAccepted>()
            .having((s) => s.pickupProximity, 'pickupProximity', PickupProximity.nearby)
            .having((s) => s.distanceToDestinationMeters, 'dist', 1200),
      ],
    );
  });

  group('Reidratação pela consulta da viagem (LoadTravel)', () {
    blocTest<TravelTrackingBloc, TravelTrackingState>(
      'viagem Accepted já com Arrived abre o card com a indicação',
      build: () {
        when(() => repository.getTravel('travel-1'))
            .thenAnswer((_) async => _accepted(pickupProximity: PickupProximity.arrived));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const LoadTravel('travel-1')),
      expect: () => [
        const TravelTrackingLoading(),
        isA<TravelTrackingAccepted>()
            .having((s) => s.pickupProximity, 'pickupProximity', PickupProximity.arrived),
      ],
    );

    blocTest<TravelTrackingBloc, TravelTrackingState>(
      'poll que traz proximidade nova atualiza o card mesmo com o mesmo motorista',
      build: () {
        when(() => repository.getTravel('travel-1'))
            .thenAnswer((_) async => _accepted(pickupProximity: PickupProximity.nearby));
        return buildBloc();
      },
      seed: () => _acceptedState(),
      act: (bloc) => bloc.add(const PollTravelStatus('travel-1')),
      expect: () => [
        isA<TravelTrackingAccepted>()
            .having((s) => s.pickupProximity, 'pickupProximity', PickupProximity.nearby),
      ],
    );

    blocTest<TravelTrackingBloc, TravelTrackingState>(
      'poll atrasado com None não apaga uma indicação já recebida por SignalR',
      build: () {
        when(() => repository.getTravel('travel-1'))
            .thenAnswer((_) async => _accepted());
        return buildBloc();
      },
      seed: () => _acceptedState(pickupProximity: PickupProximity.arrived),
      act: (bloc) => bloc.add(const PollTravelStatus('travel-1')),
      expect: () => <TravelTrackingState>[],
    );
  });

  group('Limpeza ao iniciar ou cancelar', () {
    blocTest<TravelTrackingBloc, TravelTrackingState>(
      'TravelStarted leva a InProgress, que não carrega indicação de proximidade',
      build: buildBloc,
      seed: () => _acceptedState(pickupProximity: PickupProximity.arrived),
      act: (bloc) => bloc.add(const TravelStarted({'travelId': 'travel-1'})),
      expect: () => [isA<TravelTrackingInProgress>()],
    );

    blocTest<TravelTrackingBloc, TravelTrackingState>(
      'TravelCancelled leva a Cancelled',
      build: buildBloc,
      seed: () => _acceptedState(pickupProximity: PickupProximity.nearby),
      act: (bloc) => bloc.add(const TravelCancelled({'travelId': 'travel-1', 'reason': 'x'})),
      expect: () => [isA<TravelTrackingCancelled>()],
    );
  });
}
