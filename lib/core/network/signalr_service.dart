import 'dart:async';
import 'package:signalr_netcore/signalr_client.dart';

class SignalRService {
  final _connections = <String, HubConnection>{};

  /// Último payload de `DriverContacted` recebido, independente de haver um
  /// listener inscrito no stream no momento — cobre o caso em que o backend
  /// despacha para o primeiro motorista antes da tela que exibe esse evento
  /// (WaitingPage) sequer ter montado e assinado o stream.
  Map<String, dynamic>? _lastDriverContacted;
  Map<String, dynamic>? get lastDriverContacted => _lastDriverContacted;

  final _newOrderController = StreamController<Map<String, dynamic>>.broadcast();
  final _driverContactedController = StreamController<Map<String, dynamic>>.broadcast();
  final _orderAcceptedController = StreamController<Map<String, dynamic>>.broadcast();
  final _orderCancelledController = StreamController<Map<String, dynamic>>.broadcast();
  final _travelStartedController = StreamController<Map<String, dynamic>>.broadcast();
  final _travelCompletedController = StreamController<Map<String, dynamic>>.broadcast();
  final _travelCancelledController = StreamController<Map<String, dynamic>>.broadcast();
  final _driverLocationController = StreamController<Map<String, dynamic>>.broadcast();
  final _distanceUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  final _reconnectingController = StreamController<void>.broadcast();
  final _reconnectedController = StreamController<void>.broadcast();
  final _closedController = StreamController<void>.broadcast();

  Stream<Map<String, dynamic>> get onNewOrder => _newOrderController.stream;
  Stream<Map<String, dynamic>> get onDriverContacted => _driverContactedController.stream;
  Stream<Map<String, dynamic>> get onOrderAccepted => _orderAcceptedController.stream;
  Stream<Map<String, dynamic>> get onOrderCancelled => _orderCancelledController.stream;
  Stream<Map<String, dynamic>> get onTravelStarted => _travelStartedController.stream;
  Stream<Map<String, dynamic>> get onTravelCompleted => _travelCompletedController.stream;
  Stream<Map<String, dynamic>> get onTravelCancelled => _travelCancelledController.stream;
  Stream<Map<String, dynamic>> get onDriverLocationUpdated => _driverLocationController.stream;
  Stream<Map<String, dynamic>> get onDistanceUpdate => _distanceUpdateController.stream;
  Stream<void> get onReconnecting => _reconnectingController.stream;
  Stream<void> get onReconnected => _reconnectedController.stream;
  Stream<void> get onClosed => _closedController.stream;

  /// Se já existe uma conexão viva (`Connected`) para [hubName].
  bool isConnected(String hubName) =>
      _connections[hubName]?.state == HubConnectionState.Connected;

  /// Conecta a um hub específico, identificado por [hubName].
  /// Se já existir uma conexão *viva* com o mesmo nome, não faz nada — evita
  /// que uma chamada defensiva (ex.: de uma tela que monta depois de outra
  /// já ter conectado) derrube uma conexão em uso e cause perda de eventos
  /// na troca. Se a conexão existente não estiver mais `Connected`, é
  /// recriada normalmente.
  Future<void> connect(String hubName, String hubUrl, String accessToken) async {
    if (isConnected(hubName)) return;

    await _connections[hubName]?.stop();
    _connections.remove(hubName);

    final connection = HubConnectionBuilder()
        .withUrl(hubUrl, options: HttpConnectionOptions(
          accessTokenFactory: () async => accessToken,
        ))
        .withAutomaticReconnect()
        .build();

    _registerHubHandlers(connection, hubName);

    _registerLifecycleHandlers(connection);

    await connection.start();
    _connections[hubName] = connection;
  }

  /// Desconecta apenas o hub especificado.
  Future<void> disconnect(String hubName) async {
    await _connections[hubName]?.stop();
    _connections.remove(hubName);
  }

  /// Desconecta todos os hubs.
  Future<void> disconnectAll() async {
    for (final conn in _connections.values) {
      await conn.stop();
    }
    _connections.clear();
  }

  /// Reports the current location to the backend for dashboard map tracking.
  Future<void> reportLocation(double latitude, double longitude) async {
    final conn = _connections['travel-management'];
    await conn?.invoke('ReportLocation', args: [latitude, longitude]);
  }

  /// Envia um comando 'DenyOrder' para o hub de travel-orders.
  Future<void> denyOrder(String orderId) async {
    final conn = _connections['travel-orders'];
    await conn?.invoke('DenyOrder', args: [orderId]);
  }

  /// Envia um comando 'CancelOrder' para o hub de travel-orders.
  /// Usado pelo passageiro para cancelar seu proprio pedido.
  Future<void> cancelOrder(String orderId) async {
    final conn = _connections['travel-orders'];
    await conn?.invoke('CancelOrder', args: [orderId]);
  }

  void _registerHubHandlers(HubConnection connection, String hubName) {
    switch (hubName) {
      case 'travel-orders':
        connection.on('NewOrder', (args) {
          if (args != null && args.isNotEmpty) {
            _newOrderController.add(args.first as Map<String, dynamic>);
          }
        });
        connection.on('DriverContacted', (args) {
          if (args != null && args.isNotEmpty) {
            final data = args.first as Map<String, dynamic>;
            _lastDriverContacted = data;
            _driverContactedController.add(data);
          }
        });
        connection.on('OrderAccepted', (args) {
          if (args != null && args.isNotEmpty) {
            _orderAcceptedController.add(args.first as Map<String, dynamic>);
          }
        });
        connection.on('OrderCancelled', (args) {
          if (args != null && args.isNotEmpty) {
            _orderCancelledController.add(args.first as Map<String, dynamic>);
          }
        });
        break;

      case 'travel-management':
        connection.on('TravelStarted', (args) {
          if (args != null && args.isNotEmpty) {
            _travelStartedController.add(args.first as Map<String, dynamic>);
          }
        });
        connection.on('TravelCompleted', (args) {
          if (args != null && args.isNotEmpty) {
            _travelCompletedController.add(args.first as Map<String, dynamic>);
          }
        });
        connection.on('TravelCancelled', (args) {
          if (args != null && args.isNotEmpty) {
            _travelCancelledController.add(args.first as Map<String, dynamic>);
          }
        });
        connection.on('DriverLocationUpdated', (args) {
          if (args != null && args.isNotEmpty) {
            _driverLocationController.add(args.first as Map<String, dynamic>);
          }
        });
        connection.on('DistanceUpdate', (args) {
          if (args != null && args.isNotEmpty) {
            _distanceUpdateController.add(args.first as Map<String, dynamic>);
          }
        });
        break;
    }
  }

  void _registerLifecycleHandlers(HubConnection connection) {
    connection.onreconnecting(({error}) {
      _reconnectingController.add(null);
    });

    connection.onreconnected(({connectionId}) {
      _reconnectedController.add(null);
    });

    connection.onclose(({error}) {
      _closedController.add(null);
    });
  }

  void dispose() {
    disconnectAll();
    _newOrderController.close();
    _driverContactedController.close();
    _orderAcceptedController.close();
    _orderCancelledController.close();
    _travelStartedController.close();
    _travelCompletedController.close();
    _travelCancelledController.close();
    _driverLocationController.close();
    _distanceUpdateController.close();
    _reconnectingController.close();
    _reconnectedController.close();
    _closedController.close();
  }
}
