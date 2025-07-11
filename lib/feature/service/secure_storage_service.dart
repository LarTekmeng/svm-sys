import 'package:online_doc_savimex/app_import.dart';

class SecureStorageService {
  static const _accessToken  = 'ACCESS_TOKEN';
  static const _refreshToken = 'REFRESH_TOKEN';
  static const _keyEmployee  = 'EMPLOYEE_JSON';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // ─── Access Token ───────────────────────────────────────────────────────────

  Future<void> writeAccessToken(String token) =>
      _storage.write(key: _accessToken, value: token);

  Future<String?> readAccessToken() =>
      _storage.read(key: _accessToken);

  Future<void> deleteAccessToken() =>
      _storage.delete(key: _accessToken);

  // ─── Refresh Token ──────────────────────────────────────────────────────────

  Future<void> writeRefreshToken(String token) =>
      _storage.write(key: _refreshToken, value: token);

  Future<String?> readRefreshToken() =>
      _storage.read(key: _refreshToken);

  Future<void> deleteRefreshToken() =>
      _storage.delete(key: _refreshToken);

  // ─── Employee JSON ──────────────────────────────────────────────────────────

  Future<void> writeEmployee(String json) =>
      _storage.write(key: _keyEmployee, value: json);

  Future<String?> readEmployee() =>
      _storage.read(key: _keyEmployee);

  Future<void> deleteEmployee() =>
      _storage.delete(key: _keyEmployee);

  // ─── Clear All ──────────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
