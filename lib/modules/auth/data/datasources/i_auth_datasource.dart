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
}
