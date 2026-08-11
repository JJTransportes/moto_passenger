import 'dart:developer';

import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_passenger/core/auth/auth_storage.dart';
import 'package:moto_passenger/core/local_db/repositories/auth_local_repository.dart';
import 'package:moto_passenger/core/local_db/repositories/profile_local_repository.dart';
import 'package:moto_passenger/core/local_db/repositories/travel_local_repository.dart';
import 'package:moto_passenger/core/notifications/push_notification_service.dart';

class SignOutService {
  final AuthStorage _authStorage;
  final AuthLocalRepository _authLocal;
  final ProfileLocalRepository _profileLocal;
  final TravelLocalRepository _travelLocal;
  final PushNotificationService _pushService;

  SignOutService(
    this._authStorage,
    this._authLocal,
    this._profileLocal,
    this._travelLocal,
    this._pushService,
  );

  Future<void> signOut() async {
    // Desassociar dispositivo do OneSignal (antes de limpar tokens)
    try {
      await _pushService.logout();
    } catch (e) {
      log('[PUSH] SignOutService.logout failed: $e');
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
