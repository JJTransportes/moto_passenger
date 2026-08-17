import 'dart:async';
import 'dart:developer';

import 'package:moto_passenger/core/config/app_config.dart';
import 'package:moto_passenger/core/notifications/push_notification_data.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._();
  factory PushNotificationService() => _instance;
  PushNotificationService._();
  final _foregroundController =
      StreamController<PushNotificationData>.broadcast();
  final _tapController = StreamController<PushNotificationData>.broadcast();
  final _playerIdController = StreamController<String>.broadcast();

  String? _playerId;

  Stream<PushNotificationData> get onForegroundNotification =>
      _foregroundController.stream;
  Stream<PushNotificationData> get onNotificationTap => _tapController.stream;
  Stream<String> get onPlayerIdChanged => _playerIdController.stream;
  String? get playerId => _playerId;

  Future<void> initialize() async {
    try {
      OneSignal.initialize(AppConfig.getOneSignalAppId());

      // Foreground: suprimir popup nativo (SignalR já trata o fluxo)
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        event.preventDefault();
        final data = _parseNotification(event.notification);
        _foregroundController.add(data);
      });

      // Tap na notificação (background/closed)
      OneSignal.Notifications.addClickListener((event) {
        final data = _parseNotification(event.notification);
        _tapController.add(data);
      });

      // Obter playerId (assíncrono — pode demorar após init)
      _updatePlayerId(OneSignal.User.pushSubscription.id);

      // Observer para mudanças futuras de subscription
      OneSignal.User.pushSubscription.addObserver((state) {
        _updatePlayerId(state.current.id);
      });

      log('[PUSH] Initialized. AppId=${AppConfig.getOneSignalAppId()}');
    } catch (e, st) {
      log('[PUSH] Init failed: $e', stackTrace: st);
    }
  }

  void _updatePlayerId(String? id) {
    if (id != null && id != _playerId) {
      _playerId = id;
      _playerIdController.add(id);
      log('[PUSH] PlayerId=$id');
    }
  }

  /// Associa o dispositivo ao usuário no OneSignal.
  /// OBRIGATÓRIO — backend usa include_external_user_ids para targeting.
  Future<void> login(String userId) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await OneSignal.login(userId);
        log('[PUSH] OneSignal.login OK. userId=$userId');
        return;
      } catch (e) {
        log('[PUSH] OneSignal.login attempt ${attempt + 1}/3 failed: $e');
        if (attempt < 2) {
          await Future.delayed(Duration(seconds: 1 << attempt));
        }
      }
    }
    log('[PUSH] OneSignal.login permanently failed. Continuing without push.');
  }

  /// Desassocia o dispositivo do usuário no OneSignal.
  Future<void> logout() async {
    try {
      await OneSignal.logout();
      log('[PUSH] OneSignal.logout OK');
    } catch (e) {
      log('[PUSH] OneSignal.logout failed: $e');
    }
  }

  /// Solicita permissão de notificação ao usuário.
  Future<bool> requestPermission() async {
    try {
      final granted = await OneSignal.Notifications.requestPermission(true);
      log('[PUSH] Permission granted=$granted');
      return granted;
    } catch (e) {
      log('[PUSH] Permission request failed: $e');
      return false;
    }
  }

  /// Retorna o status atual da permissão de notificação.
  bool hasPermission() {
    try {
      return OneSignal.Notifications.permission;
    } catch (_) {
      return false;
    }
  }

  PushNotificationData _parseNotification(OSNotification notification) {
    final additional = notification.additionalData ?? {};
    return PushNotificationData(
      type: additional['type'] as String? ?? '',
      travelId: additional['travelId'] as String?,
      orderId: additional['orderId'] as String?,
      title: notification.title ?? '',
      body: notification.body ?? '',
      rawPayload: Map<String, dynamic>.from(additional),
    );
  }

  void dispose() {
    _foregroundController.close();
    _tapController.close();
    _playerIdController.close();
  }
}
