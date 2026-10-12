// PSG-07: PassengerHomeBloc não tinha nenhum teste — cobre especificamente a
// estratégia "cache local primeiro, servidor é a fonte de verdade" descrita
// em PSG-12 (achado positivo da auditoria): quando o perfil falha ao buscar
// do servidor mas existe algo em cache, a Home deve mostrar o cache em vez
// de uma tela de erro pura.
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:result_dart/result_dart.dart';
import 'package:moto_passenger/core/local_db/models/local_data_models.dart';
import 'package:moto_passenger/core/local_db/repositories/profile_local_repository.dart';
import 'package:moto_passenger/core/local_db/repositories/travel_local_repository.dart';
import 'package:moto_passenger/modules/passenger_home/domain/entities/passenger_profile_entity.dart';
import 'package:moto_passenger/modules/passenger_home/domain/entities/travel_summary_entity.dart';
import 'package:moto_passenger/modules/passenger_home/domain/usecases/i_get_passenger_profile_usecase.dart';
import 'package:moto_passenger/modules/passenger_home/domain/usecases/i_get_travels_usecase.dart';
import 'package:moto_passenger/modules/passenger_home/presentation/blocs/passenger_home_bloc.dart';
import 'package:moto_passenger/modules/passenger_home/presentation/blocs/passenger_home_event.dart';
import 'package:moto_passenger/modules/passenger_home/presentation/blocs/passenger_home_state.dart';

class MockGetProfile extends Mock implements IGetPassengerProfileUsecase {}

class MockGetActiveTravel extends Mock implements IGetActiveTravelUsecase {}

class MockGetLastTravels extends Mock implements IGetLastTravelsUsecase {}

class MockProfileLocalRepository extends Mock implements ProfileLocalRepository {}

class MockTravelLocalRepository extends Mock implements TravelLocalRepository {}

const _profile = PassengerProfileEntity(id: 'p-1', fullName: 'Maria', email: 'maria@example.com');

void main() {
  late MockGetProfile getProfile;
  late MockGetActiveTravel getActiveTravel;
  late MockGetLastTravels getLastTravels;
  late MockProfileLocalRepository profileLocal;
  late MockTravelLocalRepository travelLocal;

  setUpAll(() {
    registerFallbackValue(<TravelSummaryEntity>[]);
  });

  setUp(() {
    getProfile = MockGetProfile();
    getActiveTravel = MockGetActiveTravel();
    getLastTravels = MockGetLastTravels();
    profileLocal = MockProfileLocalRepository();
    travelLocal = MockTravelLocalRepository();

    when(() => profileLocal.saveProfile(
          userId: any(named: 'userId'),
          fullName: any(named: 'fullName'),
          email: any(named: 'email'),
          photoUrl: any(named: 'photoUrl'),
        )).thenAnswer((_) async {});
    when(() => travelLocal.saveActiveTravel(any())).thenAnswer((_) async {});
    when(() => travelLocal.cacheTravels(any())).thenAnswer((_) async {});
  });

  PassengerHomeBloc buildBloc() => PassengerHomeBloc(
        getProfile: getProfile,
        getActiveTravel: getActiveTravel,
        getLastTravels: getLastTravels,
        profileLocal: profileLocal,
        travelLocal: travelLocal,
      );

  group('LoadPassengerHome', () {
    blocTest<PassengerHomeBloc, PassengerHomeState>(
      'sucesso: carrega perfil, viagem ativa e histórico, e salva tudo em cache',
      build: () {
        when(() => travelLocal.getActiveTravel()).thenAnswer((_) async => null);
        when(() => travelLocal.getCachedTravels()).thenAnswer((_) async => []);
        when(() => getProfile()).thenAnswer((_) async => const Success(_profile));
        when(() => getActiveTravel()).thenAnswer((_) async => const Success([]));
        when(() => getLastTravels()).thenAnswer((_) async => const Success([]));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const LoadPassengerHome()),
      expect: () => [
        const PassengerHomeLoading(),
        isA<PassengerHomeLoaded>()
            .having((s) => s.profile, 'profile', _profile)
            .having((s) => s.currentTravel, 'currentTravel', isNull),
      ],
      verify: (_) {
        verify(() => profileLocal.saveProfile(
              userId: 'p-1',
              fullName: 'Maria',
              email: 'maria@example.com',
              photoUrl: null,
            )).called(1);
      },
    );

    blocTest<PassengerHomeBloc, PassengerHomeState>(
      // PSG-12: perfil falha ao buscar do servidor, mas existe cache local —
      // a Home deve mostrar o cache em vez de uma tela de erro pura.
      'PSG-12: perfil falha mas há cache local — mostra os dados cacheados',
      build: () {
        final cachedTravel = TravelLocalData(
          travelId: 't-1',
          status: 'InProgress',
          createdAt: DateTime(2026, 1, 1),
        );
        when(() => travelLocal.getActiveTravel()).thenAnswer((_) async => cachedTravel);
        when(() => travelLocal.getCachedTravels()).thenAnswer((_) async => [cachedTravel]);
        when(() => getProfile()).thenAnswer((_) async => Failure(Exception('offline')));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const LoadPassengerHome()),
      expect: () => [
        const PassengerHomeLoading(),
        isA<PassengerHomeLoaded>()
            .having((s) => s.currentTravel?.travelId, 'currentTravel.travelId', 't-1')
            .having((s) => s.lastTravels.length, 'lastTravels.length', 1),
      ],
      verify: (_) {
        // Sem cache disponível, o fluxo não deveria sequer chamar os usecases
        // de viagem — a resposta já veio inteiramente do cache local.
        verifyNever(() => getActiveTravel());
        verifyNever(() => getLastTravels());
      },
    );

    blocTest<PassengerHomeBloc, PassengerHomeState>(
      'perfil falha e não há nenhum cache — emite falha',
      build: () {
        when(() => travelLocal.getActiveTravel()).thenAnswer((_) async => null);
        when(() => travelLocal.getCachedTravels()).thenAnswer((_) async => []);
        when(() => getProfile()).thenAnswer((_) async => Failure(Exception('offline')));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const LoadPassengerHome()),
      expect: () => [
        const PassengerHomeLoading(),
        isA<PassengerHomeFailure>(),
      ],
    );

    blocTest<PassengerHomeBloc, PassengerHomeState>(
      'viagem ativa presente é exposta como currentTravel',
      build: () {
        final active = TravelSummaryEntity(travelId: 't-9', status: 'Accepted', createdAt: DateTime(2026, 1, 1));
        when(() => travelLocal.getActiveTravel()).thenAnswer((_) async => null);
        when(() => travelLocal.getCachedTravels()).thenAnswer((_) async => []);
        when(() => getProfile()).thenAnswer((_) async => const Success(_profile));
        when(() => getActiveTravel()).thenAnswer((_) async => Success([active]));
        when(() => getLastTravels()).thenAnswer((_) async => const Success([]));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const LoadPassengerHome()),
      expect: () => [
        const PassengerHomeLoading(),
        isA<PassengerHomeLoaded>().having((s) => s.currentTravel?.travelId, 'currentTravel.travelId', 't-9'),
      ],
    );
  });

  group('RefreshPassengerHome', () {
    blocTest<PassengerHomeBloc, PassengerHomeState>(
      'a partir de um estado carregado, atualiza silenciosamente sem voltar para Loading',
      build: () {
        when(() => getProfile()).thenAnswer((_) async => const Success(_profile));
        when(() => getActiveTravel()).thenAnswer((_) async => const Success([]));
        when(() => getLastTravels()).thenAnswer((_) async => const Success([]));
        return buildBloc();
      },
      seed: () => const PassengerHomeLoaded(profile: _profile, lastTravels: []),
      act: (bloc) => bloc.add(const RefreshPassengerHome()),
      expect: () => [
        isA<PassengerHomeLoaded>(),
      ],
    );

    blocTest<PassengerHomeBloc, PassengerHomeState>(
      'fora de um estado carregado, cai de volta no fluxo completo de LoadPassengerHome',
      build: () {
        when(() => travelLocal.getActiveTravel()).thenAnswer((_) async => null);
        when(() => travelLocal.getCachedTravels()).thenAnswer((_) async => []);
        when(() => getProfile()).thenAnswer((_) async => const Success(_profile));
        when(() => getActiveTravel()).thenAnswer((_) async => const Success([]));
        when(() => getLastTravels()).thenAnswer((_) async => const Success([]));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const RefreshPassengerHome()),
      expect: () => [
        const PassengerHomeLoading(),
        isA<PassengerHomeLoaded>(),
      ],
    );
  });
}
