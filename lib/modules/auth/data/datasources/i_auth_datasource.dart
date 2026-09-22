import 'package:moto_passenger/modules/auth/data/models/password_policy_model.dart';
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

  /// Solicita o código de redefinição de senha para [email] (envia
  /// `expectedRole: "Passenger"` fixo, já que este app é exclusivo desse
  /// perfil).
  ///
  /// Lança [NotFoundException] com a mensagem do servidor quando o e-mail não
  /// está cadastrado (ou está cadastrado só com outra role) — decisão de
  /// segurança do backend, o app expõe essa mensagem ao usuário (não é mais
  /// anti-enumeração). [RateLimitedException] e falhas de rede/servidor
  /// também são propagadas.
  Future<void> requestPasswordReset(String email);

  /// Verifica o [code] de 6 dígitos recebido por e-mail para [email] e retorna
  /// o `resetToken` de uso único (válido por 10 min) a ser usado em
  /// [confirmPasswordReset].
  ///
  /// Lança [ValidationException] (código inválido/expirado),
  /// [ConflictException] (código já utilizado) ou [RateLimitedException] (5
  /// tentativas erradas em 30 min).
  Future<String> verifyPasswordResetCode({
    required String email,
    required String code,
  });

  /// Confirma a redefinição de senha com o [resetToken] obtido em
  /// [verifyPasswordResetCode] e a [newPassword].
  ///
  /// Lança [ValidationException] (token inválido/expirado ou senha fora da
  /// política — a mensagem do servidor distingue os dois) ou
  /// [ConflictException] (token já utilizado).
  Future<void> confirmPasswordReset({
    required String resetToken,
    required String newPassword,
  });

  /// Busca a política de senha vigente (`GET /api/auth/password-policy`,
  /// público, sem auth).
  Future<PasswordPolicyModel> getPasswordPolicy();
}
