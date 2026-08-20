import 'dart:developer';

import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_passenger/core/auth/auth_storage.dart';
import 'package:moto_passenger/core/local_db/repositories/auth_local_repository.dart';
import 'package:moto_passenger/core/local_db/repositories/profile_local_repository.dart';
import 'package:moto_passenger/core/local_db/repositories/travel_local_repository.dart';
import 'package:moto_passenger/core/notifications/push_notification_service.dart';
import 'package:moto_passenger/modules/auth/data/datasources/i_auth_datasource.dart';

class SignOutService {
  final AuthStorage _authStorage;
  final AuthLocalRepository _authLocal;
  final ProfileLocalRepository _profileLocal;
  final TravelLocalRepository _travelLocal;
  final PushNotificationService _pushService;
  final IAuthDatasource _authDatasource;

  SignOutService(
    this._authStorage,
    this._authLocal,
    this._profileLocal,
    this._travelLocal,
    this._pushService,
    this._authDatasource,
  );

  Future<void> signOut() async {
    // Desassociar dispositivo do OneSignal (antes de limpar tokens)
    try {
      await _pushService.logout();
    } catch (e) {
      log('[PUSH] SignOutService.logout failed: $e');
    }

    // Neutralizar vínculo de device no backend (best-effort, com access token
    // ainda disponível no storage). Sem isso, a sessão continua vinculada ao
    // tipo de dispositivo e bloqueia login de outro tipo.
    try {
      await _authDatasource.signOut();
    } catch (e) {
      log('[AUTH] SignOutService.backend sign-out failed: $e');
    }

    await Future.wait([
      _authStorage.clear(),
      _authLocal.clearAuth(),
      _profileLocal.clearProfile(),
      _travelLocal.clearTravels(),
    ]);
    Modular.to.navigate('/login');
  }
}
