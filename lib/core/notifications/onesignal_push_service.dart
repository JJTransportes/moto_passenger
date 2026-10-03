import 'dart:async';
import 'dart:developer' as developer;

import 'package:moto_passenger/core/notifications/deep_link_holder.dart';
import 'package:moto_passenger/core/notifications/foreground_push_policy.dart';
import 'package:moto_passenger/core/notifications/i_push_notification_service.dart';
import 'package:moto_passenger/core/notifications/notification_handler.dart';
import 'package:moto_passenger/core/notifications/onesignal_gateway.dart';
import 'package:moto_passenger/core/notifications/push_notification_data.dart';
import 'package:moto_passenger/core/notifications/push_payload_parser.dart';
import 'package:moto_passenger/core/notifications/session_readiness.dart';
import 'package:moto_passenger/modules/auth/data/datasources/i_auth_datasource.dart';

/// Integração do app do passageiro com o OneSignal (spec passenger-push-notifications).
///
/// Privacidade: nenhum log leva o identificador do aparelho nem o token — só o
/// tipo da etapa e o tipo do erro, nunca o texto da exceção (que pode conter dados).
class OneSignalPushService implements IPushNotificationService {
  final IOneSignalGateway _gateway;
  final IAuthDatasource _auth;
  final Duration _initTimeout;
  final bool Function() _isSessionReady;
  final void Function(PushNotificationData data) _navigate;
  final String? Function() _travelOnScreen;
  final void Function(String message) _log;

  OneSignalPushService(
    this._gateway,
    this._auth, {
    Duration initTimeout = const Duration(seconds: 8),
    bool Function()? isSessionReady,
    void Function(PushNotificationData data)? navigate,
    String? Function()? travelOnScreen,
    void Function(String message)? log,
  })  : _initTimeout = initTimeout,
        _isSessionReady = isSessionReady ?? (() => SessionReadiness.isReady),
        _navigate = navigate ?? NotificationHandler.handleNotificationTap,
        _travelOnScreen = travelOnScreen ?? NotificationHandler.travelOnScreen,
        _log = log ?? ((message) => developer.log(message, name: 'push'));

  Future<void>? _initFuture;
  bool _initialized = false;

  /// Usuário que deve estar identificado (pedido antes ou depois da inicialização).
  String? _wantedUserId;

  /// Usuário já identificado no SDK.
  String? _identifiedUserId;

  /// Último par (usuário, aparelho) registrado no backend — evita repetição.
  String? _registeredKey;

  @override
  Future<void> initialize(String appId) => _initFuture ??= _initialize(appId);

  Future<void> _initialize(String appId) async {
    if (appId.trim().isEmpty) {
      _log('[PUSH] ONE_SIGNAL_ID not configured; running without push.');
      return;
    }
    if (!_gateway.isSupported) {
      _log('[PUSH] Platform without push support; skipping.');
      return;
    }

    try {
      await _gateway.initialize(appId.trim()).timeout(_initTimeout);
      _gateway.onSubscriptionChanged(_onSubscriptionChanged);
      _gateway.onNotificationClicked(_onClicked);
      _gateway.onNotificationWillDisplay(_shouldSuppressInForeground);
      _initialized = true;
      _log('[PUSH] Initialized.');
    } on TimeoutException {
      _log('[PUSH] Initialization timed out; continuing without blocking the app.');
      return;
    } catch (e) {
      _log('[PUSH] Initialization failed (${e.runtimeType}); continuing without push.');
      return;
    }

    // Identificação pedida antes do fim da inicialização.
    final wanted = _wantedUserId;
    if (wanted != null) {
      await _applyIdentity(wanted);
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!_initialized) return false;
    try {
      return await _gateway.requestPermission();
    } catch (e) {
      _log('[PUSH] Permission request failed (${e.runtimeType}).');
      return false;
    }
  }

  @override
  Future<void> identify(String userId) async {
    final id = userId.trim();
    if (id.isEmpty) return;

    _wantedUserId = id;
    if (!_initialized) return; // aplicado ao fim da inicialização

    await _applyIdentity(id);
  }

  Future<void> _applyIdentity(String userId) async {
    try {
      await _gateway.login(userId);
      _identifiedUserId = userId;
    } catch (e) {
      _log('[PUSH] Identify failed (${e.runtimeType}).');
      return;
    }

    // Se um logout chegou durante o login, não registra para um usuário que saiu.
    if (_wantedUserId != userId) return;
    await _registerDevice(userId);
  }

  @override
  Future<void> clear() async {
    _wantedUserId = null;
    _identifiedUserId = null;
    _registeredKey = null;
    if (!_initialized) return;

    try {
      await _gateway.logout();
    } catch (e) {
      _log('[PUSH] Logout failed (${e.runtimeType}).');
    }
  }

  // ─── Registro do aparelho ───────────────────────────────────────────────

  void _onSubscriptionChanged(String? id) {
    final userId = _identifiedUserId;
    if (userId == null || _wantedUserId != userId) return;
    unawaited(_registerDevice(userId));
  }

  Future<void> _registerDevice(String userId) async {
    final playerId = _gateway.pushSubscriptionId;
    if (playerId == null || playerId.isEmpty) return; // o observer chama de novo

    final key = '$userId|$playerId';
    if (_registeredKey == key) return;

    try {
      await _auth.registerDeviceToken(playerId, _gateway.platform);
      _registeredKey = key;
      _log('[PUSH] Device registered.');
    } catch (e) {
      // Nunca o texto da exceção nem o identificador: só o tipo do erro.
      _log('[PUSH] Device registration failed (${e.runtimeType}).');
    }
  }

  // ─── Toque e primeiro plano ─────────────────────────────────────────────

  void _onClicked(PushNotificationContent content) {
    final data = PushPayloadParser.parse(
      additionalData: content.additionalData,
      title: content.title,
      body: content.body,
    );

    // Sessão não pronta (app abrindo, sessão expirada rumo ao login): guarda; será
    // aberto ao entrar na tela inicial.
    if (!_isSessionReady()) {
      DeepLinkHolder.store(data);
      return;
    }

    try {
      _navigate(data);
    } catch (e) {
      _log('[PUSH] Failed to open notification (${e.runtimeType}).');
    }
  }

  bool _shouldSuppressInForeground(PushNotificationContent content) {
    try {
      final data = PushPayloadParser.parse(
        additionalData: content.additionalData,
        title: content.title,
        body: content.body,
      );
      return ForegroundPushPolicy.shouldSuppress(
        type: data.type,
        travelId: data.travelId,
        travelOnScreen: _travelOnScreen(),
      );
    } catch (_) {
      // Na dúvida, mostra o aviso: perder uma notificação é pior que duplicá-la.
      return false;
    }
  }
}
