// Spec passenger-push-notifications (req 4.7, 5.5, 5.6, 7.3): leitura tolerante do
// conteúdo da notificação — só tipo e identificadores, sem dados pessoais.
import 'package:flutter_test/flutter_test.dart';
import 'package:moto_passenger/core/notifications/push_payload_parser.dart';

void main() {
  group('PushPayloadParser.parse', () {
    test('lê tipo, viagem, título e corpo de uma notificação completa', () {
      final data = PushPayloadParser.parse(
        additionalData: {'type': 'DriverArrived', 'travelId': 'travel-1'},
        title: 'Seu motorista chegou',
        body: 'O motorista está no ponto de embarque.',
      );

      expect(data.type, 'DriverArrived');
      expect(data.travelId, 'travel-1');
      expect(data.orderId, isNull);
      expect(data.title, 'Seu motorista chegou');
      expect(data.body, 'O motorista está no ponto de embarque.');
    });

    // O backend serializa o `data` do push em snake_case (JsonNamingPolicy.SnakeCaseLower):
    // o travelId chega como `travel_id`. Sem ler essa chave o toque cai na tela inicial e a
    // supressão em primeiro plano nunca casa a viagem.
    test('lê o travel_id em snake_case, que é como o backend envia', () {
      final data = PushPayloadParser.parse(
        additionalData: {'type': 'DriverArrived', 'travel_id': 'travel-1'},
      );

      expect(data.travelId, 'travel-1');
      expect(data.rawPayload['travelId'], 'travel-1');
    });

    test('o payload exato do backend para cada tipo é lido por completo', () {
      for (final type in ['OrderAccepted', 'DriverNearby', 'DriverArrived']) {
        final data = PushPayloadParser.parse(
          additionalData: {'type': type, 'travel_id': 't-9'},
        );

        expect(data.type, type);
        expect(data.travelId, 't-9', reason: type);
      }
    });

    test('travel_id vazio ou com tipo inesperado vira nulo', () {
      expect(PushPayloadParser.parse(additionalData: {'type': 'x', 'travel_id': ''}).travelId, isNull);
      expect(PushPayloadParser.parse(additionalData: {'type': 'x', 'travel_id': 7}).travelId, isNull);
    });

    test('camelCase continua aceito (apps e testes antigos)', () {
      final data = PushPayloadParser.parse(
        additionalData: {'type': 'DriverArrived', 'travelId': 'travel-1'},
      );

      expect(data.travelId, 'travel-1');
    });

    test('lê o orderId quando presente', () {
      final data = PushPayloadParser.parse(
        additionalData: {'type': 'OrderAccepted', 'orderId': 'order-9', 'travelId': 't'},
      );

      expect(data.orderId, 'order-9');
    });

    test('aceita a chave order_id', () {
      final data = PushPayloadParser.parse(
        additionalData: {'type': 'OrderAccepted', 'order_id': 'order-9'},
      );

      expect(data.orderId, 'order-9');
    });

    test('dados nulos viram um conteúdo vazio e seguro', () {
      final data = PushPayloadParser.parse(additionalData: null);

      expect(data.type, isEmpty);
      expect(data.travelId, isNull);
      expect(data.orderId, isNull);
      expect(data.title, isEmpty);
      expect(data.body, isEmpty);
      expect(data.rawPayload, isEmpty);
    });

    test('sem travelId o campo fica nulo', () {
      final data = PushPayloadParser.parse(additionalData: {'type': 'DriverNearby'});

      expect(data.type, 'DriverNearby');
      expect(data.travelId, isNull);
    });

    test('travelId vazio ou só com espaços vira nulo', () {
      expect(PushPayloadParser.parse(additionalData: {'type': 'x', 'travelId': ''}).travelId, isNull);
      expect(PushPayloadParser.parse(additionalData: {'type': 'x', 'travelId': '   '}).travelId, isNull);
    });

    test('tipos inesperados nos campos não lançam', () {
      final data = PushPayloadParser.parse(
        additionalData: {'type': 42, 'travelId': 7, 'orderId': true},
        title: null,
        body: null,
      );

      expect(data.type, isEmpty);
      expect(data.travelId, isNull);
      expect(data.orderId, isNull);
    });

    test('tipo desconhecido é preservado para o tratador decidir (vai para a tela inicial)', () {
      final data = PushPayloadParser.parse(additionalData: {'type': 'AlgoNovo', 'travelId': 't'});

      expect(data.type, 'AlgoNovo');
    });

    test('mantém o payload bruto como mapa com chaves em texto', () {
      final data = PushPayloadParser.parse(
        additionalData: {'type': 'DriverArrived', 'travelId': 't'},
      );

      expect(data.rawPayload, {'type': 'DriverArrived', 'travelId': 't'});
    });

    test('só repassa tipo e identificadores — ignora qualquer outro campo do payload', () {
      final data = PushPayloadParser.parse(
        additionalData: {
          'type': 'OrderAccepted',
          'travelId': 't',
          'driverName': 'João',
          'phone': '+5512999887766',
        },
      );

      expect(data.rawPayload.keys, unorderedEquals(['type', 'travelId']));
      expect(data.rawPayload.containsKey('phone'), isFalse);
      expect(data.rawPayload.containsKey('driverName'), isFalse);
    });

    test('aparar espaços do tipo e do travelId', () {
      final data = PushPayloadParser.parse(
        additionalData: {'type': '  DriverArrived  ', 'travelId': '  t-1  '},
      );

      expect(data.type, 'DriverArrived');
      expect(data.travelId, 't-1');
    });
  });
}
