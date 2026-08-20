import 'package:moto_passenger/modules/auth/data/models/sign_in_response_model.dart';

abstract class IAuthDatasource {
  /// Signs in with the given [email] and [password].
  ///
  /// Returns raw [SignInResponseModel] on success.
  /// Throws a typed exception (e.g. [UnauthorizedException], [NetworkException]) on failure.
  Future<SignInResponseModel> signIn(String email, String password);

  /// Exchanges a [refreshToken] for a new access token and refresh token (rotation).
  ///
  /// Returns raw [SignInResponseModel] on success.
  /// Throws [UnauthorizedException] if the refresh token is expired or invalid.
  Future<SignInResponseModel> refreshToken(String refreshToken);

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
