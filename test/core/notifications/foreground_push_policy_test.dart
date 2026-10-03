// Spec passenger-push-notifications (req 6.1, 6.2, 6.4): o banner do sistema só é
// suprimido quando o passageiro já vê, na tela, a viagem a que o aviso se refere.
import 'package:flutter_test/flutter_test.dart';
import 'package:moto_passenger/core/notifications/foreground_push_policy.dart';

void main() {
  group('ForegroundPushPolicy.shouldSuppress', () {
    for (final type in ['OrderAccepted', 'DriverNearby', 'DriverArrived']) {
      test('suprime $type da mesma viagem que está na tela', () {
        expect(
          ForegroundPushPolicy.shouldSuppress(
            type: type,
            travelId: 'travel-1',
            travelOnScreen: 'travel-1',
          ),
          isTrue,
        );
      });

      test('não suprime $type de outra viagem', () {
        expect(
          ForegroundPushPolicy.shouldSuppress(
            type: type,
            travelId: 'travel-1',
            travelOnScreen: 'travel-2',
          ),
          isFalse,
        );
      });

      test('não suprime $type quando nenhuma viagem está na tela', () {
        expect(
          ForegroundPushPolicy.shouldSuppress(
            type: type,
            travelId: 'travel-1',
            travelOnScreen: null,
          ),
          isFalse,
        );
      });

      test('não suprime $type sem identificador de viagem', () {
        expect(
          ForegroundPushPolicy.shouldSuppress(
            type: type,
            travelId: null,
            travelOnScreen: 'travel-1',
          ),
          isFalse,
        );
      });
    }

    test('não suprime tipo desconhecido, mesmo na mesma viagem', () {
      expect(
        ForegroundPushPolicy.shouldSuppress(
          type: 'AlgumaCoisaNova',
          travelId: 'travel-1',
          travelOnScreen: 'travel-1',
        ),
        isFalse,
      );
    });

    test('não suprime tipo vazio', () {
      expect(
        ForegroundPushPolicy.shouldSuppress(
          type: '',
          travelId: 'travel-1',
          travelOnScreen: 'travel-1',
        ),
        isFalse,
      );
    });

    test('mensagens do chat nunca são suprimidas por esta política (chat não gera push)', () {
      expect(
        ForegroundPushPolicy.shouldSuppress(
          type: 'ChatMessage',
          travelId: 'travel-1',
          travelOnScreen: 'travel-1',
        ),
        isFalse,
      );
    });

    test('comparação de viagem é exata (sem normalizar)', () {
      expect(
        ForegroundPushPolicy.shouldSuppress(
          type: 'DriverArrived',
          travelId: 'TRAVEL-1',
          travelOnScreen: 'travel-1',
        ),
        isFalse,
      );
    });

    test('viagem em branco na tela não casa com viagem em branco da notificação', () {
      expect(
        ForegroundPushPolicy.shouldSuppress(
          type: 'DriverArrived',
          travelId: '',
          travelOnScreen: '',
        ),
        isFalse,
      );
    });
  });
}
