// Spec passenger-push-notifications (req 5.1, 5.4, 5.5, 5.6, 6.3, 6.4): navegação
// por tipo, sem recriar a tela da mesma viagem, com fallback para a tela inicial.
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_passenger/core/notifications/notification_handler.dart';
import 'package:moto_passenger/core/notifications/push_notification_data.dart';

class MockModularNavigator extends Mock implements IModularNavigator {}

class _EmptyModule extends Module {}

PushNotificationData _data(String type, {String? travelId = 'travel-1'}) => PushNotificationData(
      type: type,
      travelId: travelId,
      title: 't',
      body: 'b',
      rawPayload: const {},
    );

void main() {
  late MockModularNavigator navigator;
  String currentPath = '/home';
  Map<String, dynamic>? currentArgs;

  setUp(() {
    navigator = MockModularNavigator();
    currentPath = '/home';
    currentArgs = null;
    when(() => navigator.navigate(any(), arguments: any(named: 'arguments'))).thenReturn(null);

    Modular.init(_EmptyModule());
    Modular.navigatorDelegate = navigator;
    NotificationHandler.routeReader = () => RouteSnapshot(currentPath, currentArgs);
  });

  tearDown(() {
    NotificationHandler.routeReader = NotificationHandler.modularRouteReader;
    Modular.navigatorDelegate = null;
    try {
      Modular.destroy();
    } catch (_) {}
  });

  group('navegação por tipo', () {
    for (final type in ['OrderAccepted', 'TravelStarted', 'DriverNearby', 'DriverArrived']) {
      test('$type abre o acompanhamento da viagem indicada', () {
        NotificationHandler.handleNotificationTap(_data(type));

        verify(() => navigator.navigate('/new-travel/tracking', arguments: {'travelId': 'travel-1'}))
            .called(1);
      });

      test('$type sem travelId abre a tela inicial', () {
        NotificationHandler.handleNotificationTap(_data(type, travelId: null));

        verify(() => navigator.navigate('/home', arguments: any(named: 'arguments'))).called(1);
        verifyNever(() => navigator.navigate('/new-travel/tracking', arguments: any(named: 'arguments')));
      });
    }

    for (final type in ['TravelCompleted', 'TravelCancelled']) {
      test('$type abre a tela inicial', () {
        NotificationHandler.handleNotificationTap(_data(type));

        verify(() => navigator.navigate('/home', arguments: any(named: 'arguments'))).called(1);
      });
    }

    test('tipo desconhecido abre a tela inicial sem erro', () {
      expect(() => NotificationHandler.handleNotificationTap(_data('AlgoNovo')), returnsNormally);

      verify(() => navigator.navigate('/home', arguments: any(named: 'arguments'))).called(1);
    });

    test('tipo vazio abre a tela inicial', () {
      NotificationHandler.handleNotificationTap(_data(''));

      verify(() => navigator.navigate('/home', arguments: any(named: 'arguments'))).called(1);
    });
  });

  group('mesma viagem já na tela', () {
    for (final type in ['OrderAccepted', 'DriverNearby', 'DriverArrived', 'TravelStarted']) {
      test('$type não navega de novo quando o acompanhamento da mesma viagem já está aberto', () {
        currentPath = '/new-travel/tracking';
        currentArgs = {'travelId': 'travel-1'};

        NotificationHandler.handleNotificationTap(_data(type));

        verifyNever(() => navigator.navigate(any(), arguments: any(named: 'arguments')));
      });
    }

    test('navega quando o acompanhamento aberto é de OUTRA viagem', () {
      currentPath = '/new-travel/tracking';
      currentArgs = {'travelId': 'travel-2'};

      NotificationHandler.handleNotificationTap(_data('DriverArrived'));

      verify(() => navigator.navigate('/new-travel/tracking', arguments: {'travelId': 'travel-1'}))
          .called(1);
    });

    test('navega quando a mesma viagem existe mas a tela aberta é outra', () {
      currentPath = '/home';
      currentArgs = {'travelId': 'travel-1'};

      NotificationHandler.handleNotificationTap(_data('DriverArrived'));

      verify(() => navigator.navigate('/new-travel/tracking', arguments: {'travelId': 'travel-1'}))
          .called(1);
    });
  });

  group('isViewingTravel', () {
    test('verdadeiro só no acompanhamento da mesma viagem', () {
      currentPath = '/new-travel/tracking';
      currentArgs = {'travelId': 'travel-1'};

      expect(NotificationHandler.isViewingTravel('travel-1'), isTrue);
    });

    test('falso para outra viagem', () {
      currentPath = '/new-travel/tracking';
      currentArgs = {'travelId': 'travel-2'};

      expect(NotificationHandler.isViewingTravel('travel-1'), isFalse);
    });

    test('falso em outra tela', () {
      currentPath = '/home';
      currentArgs = {'travelId': 'travel-1'};

      expect(NotificationHandler.isViewingTravel('travel-1'), isFalse);
    });

    test('falso sem argumentos', () {
      currentPath = '/new-travel/tracking';
      currentArgs = null;

      expect(NotificationHandler.isViewingTravel('travel-1'), isFalse);
    });

    test('falso para travelId nulo ou vazio', () {
      currentPath = '/new-travel/tracking';
      currentArgs = {'travelId': 'travel-1'};

      expect(NotificationHandler.isViewingTravel(null), isFalse);
      expect(NotificationHandler.isViewingTravel(''), isFalse);
    });

    test('a viagem na tela é exposta para a política de primeiro plano', () {
      currentPath = '/new-travel/tracking';
      currentArgs = {'travelId': 'travel-1'};

      expect(NotificationHandler.travelOnScreen(), 'travel-1');

      currentPath = '/home';
      expect(NotificationHandler.travelOnScreen(), isNull);
    });
  });
}
