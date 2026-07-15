import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  final FlutterSecureStorage _storage;

  static const _tokenKey = 'moto_passenger_token';
  static const _refreshTokenKey = 'moto_passenger_refresh_token';
  static const _userIdKey = 'moto_passenger_user_id';

  AuthStorage() : _storage = const FlutterSecureStorage();

  Future<void> saveTokens(String accessToken, String refreshToken, String userId) async {
    await Future.wait([
      _storage.write(key: _tokenKey, value: accessToken),
      _storage.write(key: _refreshTokenKey, value: refreshToken),
      _storage.write(key: _userIdKey, value: userId),
    ]);
  }

  Future<void> saveToken(String token, String userId) async {
    await Future.wait([
      _storage.write(key: _tokenKey, value: token),
      _storage.write(key: _userIdKey, value: userId),
    ]);
  }

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<String?> getUserId() => _storage.read(key: _userIdKey);

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _tokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _userIdKey),
    ]);
  }
}
