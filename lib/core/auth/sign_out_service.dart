import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_passenger/core/auth/auth_storage.dart';
import 'package:moto_passenger/core/local_db/repositories/auth_local_repository.dart';
import 'package:moto_passenger/core/local_db/repositories/profile_local_repository.dart';
import 'package:moto_passenger/core/local_db/repositories/travel_local_repository.dart';
import 'package:moto_passenger/core/navigation/app_messenger.dart';

class SignOutService {
  final AuthStorage _authStorage;
  final AuthLocalRepository _authLocal;
  final ProfileLocalRepository _profileLocal;
  final TravelLocalRepository _travelLocal;

  SignOutService(
    this._authStorage,
    this._authLocal,
    this._profileLocal,
    this._travelLocal,
  );

  /// Clears all local session state and navigates to `/login`.
  ///
  /// If [message] is provided (e.g. "Sua sessão expirou, faça login
  /// novamente."), it is shown as a [SnackBar] right after navigating —
  /// used by the auth interceptor when a silent token refresh fails during
  /// normal app usage, so the user understands *why* they were logged out.
  Future<void> signOut({String? message}) async {
    await Future.wait([
      _authStorage.clear(),
      _authLocal.clearAuth(),
      _profileLocal.clearProfile(),
      _travelLocal.clearTravels(),
    ]);
    Modular.to.navigate('/login');
    if (message != null) {
      showGlobalSnackBar(message);
    }
  }
}
