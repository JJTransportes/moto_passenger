import 'dart:async';
import 'package:signalr_netcore/signalr_client.dart';

class SignalRService {
  final _connections = <String, HubConnection>{};

  final _newOrderController = StreamController<Map<String, dynamic>>.broadcast();
  final _orderAcceptedController = StreamController<Map<String, dynamic>>.broadcast();
  final _noDriversAvailableController = StreamController<Map<String, dynamic>>.broadcast();
  final _travelStartedController = StreamController<Map<String, dynamic>>.broadcast();
  final _travelCompletedController = StreamController<Map<String, dynamic>>.broadcast();
  final _travelCancelledController = StreamController<Map<String, dynamic>>.broadcast();
  final _driverLocationController = StreamController<Map<String, dynamic>>.broadcast();
  final _distanceUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  final _reconnectingController = StreamController<void>.broadcast();
  final _reconnectedController = StreamController<void>.broadcast();
  final _closedController = StreamController<void>.broadcast();

  Stream<Map<String, dynamic>> get onNewOrder => _newOrderController.stream;
  Stream<Map<String, dynamic>> get onOrderAccepted => _orderAcceptedController.stream;
  Stream<Map<String, dynamic>> get onNoDriversAvailable => _noDriversAvailableController.stream;
  Stream<Map<String, dynamic>> get onTravelStarted => _travelStartedController.stream;
  Stream<Map<String, dynamic>> get onTravelCompleted => _travelCompletedController.stream;
  Stream<Map<String, dynamic>> get onTravelCancelled => _travelCancelledController.stream;
  Stream<Map<String, dynamic>> get onDriverLocationUpdated => _driverLocationController.stream;
  Stream<Map<String, dynamic>> get onDistanceUpdate => _distanceUpdateController.stream;
  Stream<void> get onReconnecting => _reconnectingController.stream;
  Stream<void> get onReconnected => _reconnectedController.stream;
  Stream<void> get onClosed => _closedController.stream;

  /// Conecta a um hub específico, identificado por [hubName].
  /// Se já existir uma conexão com o mesmo nome, ela é recriada.
  /// Não afeta conexões de outros hubs.
  Future<void> connect(String hubName, String hubUrl, String accessToken) async {
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
  Future<void> denyOrder(String travelId) async {
    final conn = _connections['travel-orders'];
    await conn?.invoke('DenyOrder', args: [travelId]);
  }

  void _registerHubHandlers(HubConnection connection, String hubName) {
    switch (hubName) {
      case 'travel-orders':
        connection.on('NewOrder', (args) {
          if (args != null && args.isNotEmpty) {
            _newOrderController.add(args.first as Map<String, dynamic>);
          }
        });
        connection.on('OrderAccepted', (args) {
          if (args != null && args.isNotEmpty) {
            _orderAcceptedController.add(args.first as Map<String, dynamic>);
          }
        });
        connection.on('NoDriversAvailable', (args) {
          if (args != null && args.isNotEmpty) {
            _noDriversAvailableController.add(args.first as Map<String, dynamic>);
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
    _orderAcceptedController.close();
    _noDriversAvailableController.close();
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
