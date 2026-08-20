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

  /// Solicita o código de redefinição de senha para [email].
  ///
  /// Não lança para e-mail não cadastrado (HTTP 404): por design anti-enumeração,
  /// "e-mail existe" e "e-mail não existe" são indistinguíveis para quem está do
  /// lado de fora. Apenas [RateLimitedException] e falhas de rede/servidor são
  /// propagadas.
  Future<void> requestPasswordReset(String email);

  /// Confirma a redefinição de senha com o [code] de 6 dígitos recebido por
  /// e-mail e a [newPassword].
  ///
  /// Lança [ValidationException] (código inválido/expirado ou senha fora da
  /// política — a mensagem do servidor distingue os dois), [ConflictException]
  /// (código já utilizado) ou [RateLimitedException].
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  });
}
