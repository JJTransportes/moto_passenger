import 'package:moto_passenger/core/local_db/local_database_service.dart';
import 'package:moto_passenger/core/local_db/models/local_data_models.dart';

class AuthLocalRepository {
  Future<void> saveAuth({
    required String userId,
    required String accessToken,
    String refreshToken = '',
    required List<String> roles,
  }) async {
    try {
      final db = LocalDatabaseService.instance;
      await _ensureRefreshTokenColumn(db);
      await db.delete('auth');
      await db.insert('auth', {
        'user_id': userId,
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'roles': roles.join(','),
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Silently fail — app works without cache
    }
  }

  Future<AuthLocalData?> getAuth() async {
    try {
      final db = LocalDatabaseService.instance;
      final rows = await db.query('auth', limit: 1);
      if (rows.isEmpty) return null;
      return AuthLocalData.fromMap(rows.first);
    } catch (_) {
      return null;
    }
  }

  Future<void> updateTokens(String accessToken, String refreshToken) async {
    try {
      final db = LocalDatabaseService.instance;
      final existing = await db.query('auth', limit: 1);
      if (existing.isEmpty) return;
      await db.update('auth', {
        'access_token': accessToken,
        'refresh_token': refreshToken,
      });
    } catch (_) {}
  }

  Future<void> clearAuth() async {
    try {
      final db = LocalDatabaseService.instance;
      await db.delete('auth');
    } catch (_) {}
  }

  Future<void> _ensureRefreshTokenColumn(db) async {
    try {
      await db.execute('ALTER TABLE auth ADD COLUMN refresh_token TEXT DEFAULT \'\'');
    } catch (_) {
      // Column already exists — ignore
    }
  }
}
