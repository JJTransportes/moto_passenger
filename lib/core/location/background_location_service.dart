import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:geolocator/geolocator.dart';
import 'package:moto_passenger/core/auth/auth_storage.dart';
import 'package:moto_passenger/core/config/app_config.dart';

const _serviceId = 7306;
const _baseUrlKey = 'passenger_background_location_base_url';
const _passengerIdKey = 'passenger_background_location_user_id';
const _tokenKey = 'passenger_background_location_token';

@pragma('vm:entry-point')
void passengerBackgroundLocationStartCallback() {
  FlutterForegroundTask.setTaskHandler(PassengerBackgroundLocationTask());
}

class PassengerBackgroundLocationTask extends TaskHandler {
  bool _sending = false;
  Position? _lastPosition;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _sendPosition();
  }

  @override
  void onRepeatEvent(DateTime timestamp) => unawaited(_sendPosition());

  Future<void> _sendPosition() async {
    if (_sending) return;
    _sending = true;
    try {
      final baseUrl = await FlutterForegroundTask.getData<String>(
        key: _baseUrlKey,
      );
      final passengerId = await FlutterForegroundTask.getData<String>(
        key: _passengerIdKey,
      );
      final token = await FlutterForegroundTask.getData<String>(key: _tokenKey);
      if (baseUrl == null || passengerId == null || token == null) return;

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 4),
        ),
      );

      final previous = _lastPosition;
      final movedEnough =
          previous == null ||
          Geolocator.distanceBetween(
                previous.latitude,
                previous.longitude,
                position.latitude,
                position.longitude,
              ) >=
              3;

      // Mesmo parado, o evento de 5 segundos funciona como heartbeat para o
      // backend não considerar a posição antiga. O limiar evita apenas ruído
      // adicional no estado local e fica pronto para filtragem adaptativa.
      await Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      ).post(
        '/api/positions/passengers/$passengerId',
        data: {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
      );

      _lastPosition = position;
      final now = DateTime.now();
      final formattedTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      await FlutterForegroundTask.updateService(
        notificationTitle: 'Motô — viagem ativa',
        notificationText: movedEnough
            ? 'Localização atualizada às $formattedTime'
            : 'Localização confirmada às $formattedTime',
      );
    } catch (error) {
      FlutterForegroundTask.sendDataToMain({
        'type': 'passenger_location_error',
        'message': error.toString(),
      });
    } finally {
      _sending = false;
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp('/home');

  @override
  void onNotificationDismissed() {}
}

enum PassengerBackgroundLocationPermission {
  granted,
  locationDenied,
  locationDeniedForever,
  backgroundLocationRequired,
  notificationsDenied,
  serviceDisabled,
  unsupported,
}

class PassengerBackgroundLocationService {
  final AuthStorage _authStorage;

  PassengerBackgroundLocationService(this._authStorage);

  // iOS: não existe foreground service. Com o modo de segundo plano `location`
  // e a permissão "Sempre", o fluxo de posições mantém o app vivo fora da tela.
  StreamSubscription<Position>? _iosSubscription;
  Timer? _iosHeartbeat;
  Position? _iosLastPosition;
  DateTime? _iosLastSentAt;
  bool _iosSending = false;
  static const _iosSendInterval = Duration(seconds: 5);

  static void initialize() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'moto_passenger_location',
        channelName: 'Localização durante a viagem',
        channelDescription:
            'Mantém sua localização atualizada enquanto existe uma solicitação ou viagem.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
        allowAutoRestart: true,
      ),
    );
  }

  Future<PassengerBackgroundLocationPermission> requestPermissions() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return PassengerBackgroundLocationPermission.unsupported;
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      return PassengerBackgroundLocationPermission.serviceDisabled;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return PassengerBackgroundLocationPermission.locationDenied;
    }
    if (permission == LocationPermission.deniedForever) {
      return PassengerBackgroundLocationPermission.locationDeniedForever;
    }

    // A permissão de notificação do serviço em primeiro plano é só do Android.
    if (Platform.isAndroid) {
      var notification =
          await FlutterForegroundTask.checkNotificationPermission();
      if (notification != NotificationPermission.granted) {
        notification =
            await FlutterForegroundTask.requestNotificationPermission();
      }
      if (notification != NotificationPermission.granted) {
        return PassengerBackgroundLocationPermission.notificationsDenied;
      }
    }
    if (permission != LocationPermission.always) {
      return PassengerBackgroundLocationPermission.backgroundLocationRequired;
    }
    return PassengerBackgroundLocationPermission.granted;
  }

  Future<bool> _startIosTracking() async {
    if (_iosSubscription != null) return true;
    final passengerId = await _authStorage.getUserId();
    if (passengerId == null) return false;

    _iosSubscription =
        Geolocator.getPositionStream(
          locationSettings: AppleSettings(
            accuracy: LocationAccuracy.high,
            activityType: ActivityType.otherNavigation,
            pauseLocationUpdatesAutomatically: false,
            showBackgroundLocationIndicator: true,
            allowBackgroundLocationUpdates: true,
          ),
        ).listen((position) {
          _iosLastPosition = position;
          unawaited(_sendIosPosition(passengerId));
        }, onError: (Object _) {});
    // Parado, o iOS não emite posições; o batimento mantém o passageiro
    // visível no mapa (a janela de "ao vivo" do dashboard é de 30 s).
    _iosHeartbeat = Timer.periodic(
      _iosSendInterval,
      (_) => unawaited(_sendIosPosition(passengerId)),
    );
    return true;
  }

  Future<void> _sendIosPosition(String passengerId) async {
    final position = _iosLastPosition;
    if (position == null || _iosSending) return;
    final lastSentAt = _iosLastSentAt;
    if (lastSentAt != null &&
        DateTime.now().difference(lastSentAt) < _iosSendInterval) {
      return;
    }
    _iosSending = true;
    try {
      await Modular.get<Dio>().post(
        '/api/positions/passengers/$passengerId',
        data: {'latitude': position.latitude, 'longitude': position.longitude},
      );
      _iosLastSentAt = DateTime.now();
    } catch (_) {
      // Falha de rede: tenta de novo no próximo batimento.
    } finally {
      _iosSending = false;
    }
  }

  Future<void> _stopIosTracking() async {
    await _iosSubscription?.cancel();
    _iosSubscription = null;
    _iosHeartbeat?.cancel();
    _iosHeartbeat = null;
    _iosLastPosition = null;
    _iosLastSentAt = null;
  }

  Future<bool> start() async {
    if (Platform.isIOS) return _startIosTracking();
    if (!Platform.isAndroid) return false;
    final token = await _authStorage.getToken();
    final passengerId = await _authStorage.getUserId();
    if (token == null || passengerId == null) return false;

    await Future.wait([
      FlutterForegroundTask.saveData(
        key: _baseUrlKey,
        value: AppConfig.getBaseUrl(),
      ),
      FlutterForegroundTask.saveData(key: _passengerIdKey, value: passengerId),
      FlutterForegroundTask.saveData(key: _tokenKey, value: token),
    ]);
    if (await FlutterForegroundTask.isRunningService) return true;

    final result = await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: const [ForegroundServiceTypes.location],
      notificationTitle: 'Motô — procurando motorista',
      notificationText: 'Compartilhando o local de embarque',
      notificationInitialRoute: '/home',
      callback: passengerBackgroundLocationStartCallback,
    );
    if (kDebugMode) debugPrint('Passenger background location start: $result');
    return result is ServiceRequestSuccess;
  }

  Future<void> stop() async {
    if (Platform.isIOS) {
      await _stopIosTracking();
      return;
    }
    if (!Platform.isAndroid) return;
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
    await Future.wait([
      FlutterForegroundTask.removeData(key: _passengerIdKey),
      FlutterForegroundTask.removeData(key: _tokenKey),
    ]);
  }

  Future<bool> requestPermissionAndStart(BuildContext context) async {
    if (Platform.isAndroid && await FlutterForegroundTask.isRunningService) {
      return start();
    }
    final permission = await requestPermissions();
    if (permission == PassengerBackgroundLocationPermission.granted) {
      return start();
    }
    // O bloqueio global exibe a orientação e impede o uso até a regularização.
    // Aqui só evitamos iniciar o serviço com permissões incompletas.
    if (!context.mounted) return false;
    return false;
  }
}
