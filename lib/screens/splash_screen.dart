import 'dart:async';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_passenger/core/auth/auth_storage.dart';
import 'package:moto_passenger/core/auth/sign_out_service.dart';
import 'package:moto_passenger/core/config/app_config.dart';
import 'package:moto_passenger/core/errors/exceptions.dart';
import 'package:moto_passenger/core/local_db/repositories/auth_local_repository.dart';
import 'package:moto_passenger/core/local_db/repositories/travel_local_repository.dart';
import 'package:moto_passenger/core/notifications/i_push_notification_service.dart';
import 'package:moto_passenger/core/notifications/deep_link_holder.dart';
import 'package:moto_passenger/core/notifications/notification_channel_service.dart';
import 'package:moto_passenger/core/notifications/session_readiness.dart';
import 'package:moto_passenger/modules/auth/data/datasources/i_auth_datasource.dart';

enum _StartupRefreshOutcome { success, invalidSession, transientFailure }

class SplashScreen extends StatefulWidget {
  final Duration delay;

  const SplashScreen({
    super.key,
    this.delay = const Duration(seconds: 2),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  /// userId da sessão restaurada pela renovação do token (para identificar no push).
  String? _restoredUserId;

  @override
  void initState() {
    super.initState();
    _initPush();
    _checkAuth();
  }

  /// Inicializa o push e pede a permissão (spec passenger-push-notifications, req 1).
  /// Em segundo plano: nunca atrasa nem bloqueia a decisão de autenticação, e uma
  /// falha aqui só é registrada.
  void _initPush() {
    unawaited(() async {
      // O canal do Android com o som do Moto precisa existir antes de o OneSignal inicializar e
      // de chegar a primeira notificação (spec push-notification-sounds). Falha só é registrada.
      try {
        await Modular.get<INotificationChannelService>()
            .ensureRideAlertsChannel();
      } catch (e) {
        log(
          '[PUSH] Notification channel failed (${e.runtimeType}).',
          name: 'push',
          level: 900,
        );
      }

      try {
        final push = Modular.get<IPushNotificationService>();
        await push.initialize(AppConfig.getOneSignalAppId());
        await push.requestPermission();
      } catch (e) {
        log(
          '[PUSH] Startup failed (${e.runtimeType}).',
          name: 'push',
          level: 900,
        );
      }
    }());
  }

  Future<void> _checkAuth() async {
    await Future.delayed(widget.delay);
    if (!mounted) return;

    // Try local DB cache first
    final authLocal = Modular.get<AuthLocalRepository>();
    final localAuth = await authLocal.getAuth();

    // If we have a refresh token, try to renew the session
    if (localAuth != null && localAuth.refreshToken.isNotEmpty) {
      final refreshOutcome = await _tryRefreshToken(localAuth.refreshToken);
      if (!mounted) return;
      if (refreshOutcome == _StartupRefreshOutcome.success) {
        await _afterAuthSuccess(_restoredUserId);
        return;
      }
      if (refreshOutcome == _StartupRefreshOutcome.transientFailure) {
        // Reabertura sem internet: mantém a sessão e restaura a viagem pelo
        // cache. O interceptor renovará o token quando a conexão voltar.
        await _afterAuthSuccess(localAuth.userId);
        return;
      }
      // O servidor confirmou token expirado/inválido.
      await Modular.get<SignOutService>().signOut(
        message: 'Sua sessão expirou, faça login novamente.',
      );
      return;
    }

    // Fallback: access token from local cache (no refresh token available)
    if (localAuth != null && localAuth.accessToken.isNotEmpty) {
      if (!mounted) return;
      await _afterAuthSuccess(localAuth.userId);
      return;
    }

    // Fallback to secure storage
    final storage = Modular.get<AuthStorage>();
    final token = await storage.getToken();

    if (!mounted) return;
    if (token != null) {
      await _afterAuthSuccess(await storage.getUserId());
    } else {
      Modular.to.navigate('/login');
    }
  }

  Future<void> _afterAuthSuccess(String? userId) async {
    _identifyForPush(userId);
    final restored = await _checkActiveTravel();
    if (!mounted) return;
    if (!restored) {
      Modular.to.navigate('/usage-terms-guard');
      return;
    }
    // Viagem ativa restaurada: a sessão está pronta. Abre o toque guardado, se houver
    // sem criar uma segunda rota de tracking. Durante o mesmo cold start o
    // clique do OneSignal e a restauração local podem chegar no mesmo frame;
    // consultar a rota atual ainda é cedo demais nesse ponto. A viagem já foi
    // aberta pela fonte canônica acima, então o deep link fica satisfeito.
    SessionReadiness.markReady();
    DeepLinkHolder.consume();
  }

  /// Identifica o aparelho no push com o usuário da sessão restaurada (req 2.2).
  /// Em segundo plano e tolerante a falha.
  void _identifyForPush(String? userId) {
    if (userId == null || userId.isEmpty) return;
    unawaited(() async {
      try {
        await Modular.get<IPushNotificationService>().identify(userId);
      } catch (e) {
        log(
          '[PUSH] Identify on session restore failed (${e.runtimeType}).',
          name: 'push',
          level: 900,
        );
      }
    }());
  }

  /// Tries to refresh the access token using the [refreshToken].
  /// Distingue sessão inválida de uma indisponibilidade temporária.
  Future<_StartupRefreshOutcome> _tryRefreshToken(String refreshToken) async {
    try {
      final authDatasource = Modular.get<IAuthDatasource>();
      final result = await authDatasource.refreshToken(refreshToken);

      final storage = Modular.get<AuthStorage>();
      final authLocal = Modular.get<AuthLocalRepository>();

      await storage.saveTokens(
        result.accessToken,
        result.refreshToken!,
        result.userId,
      );
      _restoredUserId = result.userId;
      await authLocal.updateTokens(
        result.accessToken,
        result.refreshToken!,
      );
      return _StartupRefreshOutcome.success;
    } on UnauthorizedException {
      // Refresh token expirado ou revogado — não recuperável
      return _StartupRefreshOutcome.invalidSession;
    } on ValidationException {
      return _StartupRefreshOutcome.invalidSession;
    } on DeviceMismatchException {
      // Token vinculado a outro tipo de dispositivo — não recuperável neste aparelho
      return _StartupRefreshOutcome.invalidSession;
    } catch (_) {
      return _StartupRefreshOutcome.transientFailure;
    }
  }

  /// Checks if there's an active travel in local storage and navigates to it.
  /// Returns true if restored, false if no active travel found.
  Future<bool> _checkActiveTravel() async {
    final travelRepo = Modular.get<TravelLocalRepository>();
    final active = await travelRepo.getActiveTravel();

    if (active == null ||
        active.status == 'Completed' ||
        active.status == 'Cancelled') {
      return false;
    }

    // Verify travel still exists on backend
    try {
      final dio = Modular.get<Dio>();
      await dio.get('${AppConfig.getBaseUrl()}/api/travels/${active.travelId}');
      if (active.status == 'Accepted' || active.status == 'InProgress') {
        Modular.to.pushNamed(
          '/new-travel/tracking',
          arguments: {'travelId': active.travelId},
        );
        return true;
      }
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        // Somente a confirmação do backend de que a viagem não existe permite
        // apagar o cache. Falha de rede/401 temporário mantém a viagem.
        await travelRepo.clearTravels();
        return false;
      }
      if (active.status == 'Accepted' || active.status == 'InProgress') {
        Modular.to.pushNamed(
          '/new-travel/tracking',
          arguments: {'travelId': active.travelId},
        );
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Image.asset(
          'assets/images/moto_passenger_logo.png',
          width: 257,
          height: 103,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox(
            width: 257,
            height: 103,
            child: Placeholder(),
          ),
        ),
      ),
    );
  }
}
