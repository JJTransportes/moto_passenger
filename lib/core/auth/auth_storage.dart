import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

  Future<String?> getToken() => _safeRead(_tokenKey);

  Future<String?> getRefreshToken() => _safeRead(_refreshTokenKey);

  Future<String?> getUserId() => _safeRead(_userIdKey);

  Future<String?> _safeRead(String key) async {
    try {
      return await _storage.read(key: key);
    } on PlatformException catch (e) {
      if (e.code == 'Exception encountered' &&
          e.message?.contains('read') == true) {
        debugPrint('AuthStorage: corrupted secure storage — clearing');
        await _storage.deleteAll();
        return null;
      }
      rethrow;
    }
  }

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _tokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _userIdKey),
    ]);
  }
}
