import 'package:flutter_test/flutter_test.dart';
import 'package:moto_passenger/core/network/response_data.dart';

void main() {
  group('responseDataAsMap', () {
    test('mantém uma resposta que já é mapa', () {
      expect(
        responseDataAsMap({'status': 'Accepted'}),
        {'status': 'Accepted'},
      );
    });

    test('converte objeto JSON recebido como texto', () {
      expect(
        responseDataAsMap('{"status":"Pending","orderId":"order-1"}'),
        {'status': 'Pending', 'orderId': 'order-1'},
      );
    });

    test('converte JSON que foi serializado duas vezes', () {
      expect(
        responseDataAsMap('"{\\"status\\":\\"Cancelled\\"}"'),
        {'status': 'Cancelled'},
      );
    });

    test('retorna null para texto comum ou corpo vazio', () {
      expect(responseDataAsMap('No active travel'), isNull);
      expect(responseDataAsMap(''), isNull);
      expect(responseDataAsMap(null), isNull);
    });
  });
}
