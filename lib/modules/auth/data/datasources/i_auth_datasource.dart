import 'package:moto_passenger/modules/auth/data/models/sign_in_response_model.dart';

abstract class IAuthDatasource {
  /// Signs in with the given [email] and [password].
  ///
  /// Sends the device type (`android`/`ios`) in the body when running on a
  /// mobile platform, so the backend can bind the session to the device type.
  /// Throws [DeviceConflictException] on 409 (active session on another device
  /// type).
  ///
  /// Returns raw [SignInResponseModel] on success.
  /// Throws a typed exception (e.g. [UnauthorizedException], [NetworkException]) on failure.
  Future<SignInResponseModel> signIn(String email, String password);

  /// Exchanges a [refreshToken] for a new access token and refresh token (rotation).
  ///
  /// Sends the device type in the body (see [signIn]).
  /// Throws [UnauthorizedException] if the refresh token is expired or invalid,
  /// or [DeviceMismatchException] on 403 (token bound to another device type).
  Future<SignInResponseModel> refreshToken(String refreshToken);

  /// Signs the current user out on the backend: `POST /api/auth/sign-out`.
  ///
  /// Neutralizes the device binding of all active tokens, freeing another
  /// device type to sign in. Requires a valid access token (attached by the
  /// auth interceptor). Returns normally on 204.
  Future<void> signOut();

  /// Registers the device token (OneSignal playerId) for push notifications.
  /// Idempotent — backend does UPSERT.
  Future<void> registerDeviceToken(String playerId, String platform);
}
