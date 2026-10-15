import 'dart:async';
import 'dart:developer';

import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_passenger/core/auth/auth_storage.dart';
import 'package:moto_passenger/core/local_db/repositories/auth_local_repository.dart';
import 'package:moto_passenger/core/local_db/repositories/profile_local_repository.dart';
import 'package:moto_passenger/core/local_db/repositories/travel_local_repository.dart';
import 'package:moto_passenger/core/navigation/app_messenger.dart';
import 'package:moto_passenger/core/location/background_location_service.dart';
import 'package:moto_passenger/core/notifications/i_push_notification_service.dart';
import 'package:moto_passenger/core/notifications/session_readiness.dart';
import 'package:moto_passenger/modules/auth/data/datasources/i_auth_datasource.dart';

class SignOutService {
  final AuthStorage _authStorage;
  final AuthLocalRepository _authLocal;
  final ProfileLocalRepository _profileLocal;
  final TravelLocalRepository _travelLocal;
  final IPushNotificationService _push;
  final IAuthDatasource _authDatasource;
  final Duration _pushTimeout;

  SignOutService(
    this._authStorage,
    this._authLocal,
    this._profileLocal,
    this._travelLocal,
    this._push,
    this._authDatasource, {
    Duration pushTimeout = const Duration(seconds: 3),
  }) : _pushTimeout = pushTimeout;

  /// Clears all local session state and navigates to `/login`.
  ///
  /// Também remove a identificação do aparelho no push (spec
  /// passenger-push-notifications, req 2.3 a 2.5), para ele deixar de receber os
  /// avisos desta conta — vale para logout, exclusão de conta e sessão expirada,
  /// que passam todos por aqui. Falha ou demora do push nunca impede a saída.
  ///
  /// If [message] is provided (e.g. "Sua sessão expirou, faça login
  /// novamente."), it is shown as a [SnackBar] right after navigating —
  /// used by the auth interceptor when a silent token refresh fails during
  /// normal app usage, so the user understands *why* they were logged out.
  ///
  /// Reentrante: uma chamada durante outra em andamento reaproveita a mesma
  /// execução (o 401 das chamadas feitas aqui dispara o tratamento de sessão
  /// inválida, que chama [signOut] de novo).
  Future<void> signOut({String? message}) {
    final running = _running;
    if (running != null) return running;
    final future = _performSignOut(message: message);
    _running = future;
    return future.whenComplete(() => _running = null);
  }

  Future<void>? _running;

  Future<void> _performSignOut({String? message}) async {
    // A partir daqui um toque em notificação deve ser guardado, não navegar.
    SessionReadiness.reset();

    // Device binding: libera a sessão no backend (device=NULL nos tokens ativos)
    // para que outro tipo de dispositivo possa logar. Roda ANTES de limpar o
    // storage, pois usa o access token salvo. Best-effort: falha ou demora nunca
    // impede a saída. /api/auth/* é ignorado pelo AuthErrorInterceptor, então
    // não há loop de refresh.
    await _releaseDeviceBinding();

    await Future.wait([
      _stopBackgroundLocation(),
      _authStorage.clear(),
      _authLocal.clearAuth(),
      _profileLocal.clearProfile(),
      _travelLocal.clearTravels(),
      _clearPush(),
    ]);
    Modular.to.navigate('/login');
    if (message != null) {
      showGlobalSnackBar(message);
    }
  }

  Future<void> _releaseDeviceBinding() async {
    try {
      final token = await _authStorage.getToken();
      if (token == null || token.isEmpty) return;
      await _authDatasource.signOut().timeout(_pushTimeout);
    } catch (e) {
      log(
        '[AUTH] Backend sign-out failed (${e.runtimeType}).',
        name: 'auth',
        level: 900,
      );
    }
  }

  Future<void> _stopBackgroundLocation() async {
    try {
      await Modular.get<PassengerBackgroundLocationService>().stop().timeout(
        _pushTimeout,
      );
    } catch (_) {
      // O binding pode não existir em testes unitários isolados.
    }
  }

  Future<void> _clearPush() async {
    try {
      await _push.clear().timeout(_pushTimeout);
    } catch (e) {
      log(
        '[PUSH] Clear on sign-out failed (${e.runtimeType}).',
        name: 'push',
        level: 900,
      );
    }
  }
}
