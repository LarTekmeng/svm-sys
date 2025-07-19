import 'package:online_doc_savimex/app_import.dart';

class SecureStorageService {
  static const _accessToken = 'ACCESS_TOKEN';
  static const _refreshToken = 'REFRESH_TOKEN';
  static const _keyEmployee = 'EMPLOYEE_JSON';
  bool volatileMode = false;
  final Map<String, String> _memoryCache = {};

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // ─── Access Token ───────────────────────────────────────────────────────────

  Future<void> writeAccessToken(String token) =>
      _storage.write(key: _accessToken, value: token);

  Future<String?> readAccessToken() => _storage.read(key: _accessToken);

  Future<void> deleteAccessToken() => _storage.delete(key: _accessToken);

  // ─── Refresh Token ──────────────────────────────────────────────────────────

  Future<void> writeRefreshToken(String token) =>
      _storage.write(key: _refreshToken, value: token);

  Future<String?> readRefreshToken() => _storage.read(key: _refreshToken);

  Future<void> deleteRefreshToken() => _storage.delete(key: _refreshToken);

  // ─── Employee JSON ──────────────────────────────────────────────────────────

  Future<void> writeEmployee(String json) =>
      _storage.write(key: _keyEmployee, value: json);

  Future<String?> readEmployee() => _storage.read(key: _keyEmployee);

  Future<void> deleteEmployee() => _storage.delete(key: _keyEmployee);

  // ─── REMEMBER ME ──────────────────────────────────────────────────────────────

  Future<void> writeRememberMe(bool rememberMe) =>
      _storage.write(key: 'rememberMe', value: rememberMe.toString());

  Future<String?> readRememberMe() =>
      _storage.read(key: 'rememberMe');

  Future<void> deleteRememberMe() =>
      _storage.delete(key: 'rememberMe');

  // ─── Memory Cache ──────────────────────────────────────────────────────────────

  Future<void> _write(String key, String value) async {
    if (volatileMode) {
      _memoryCache[key] = value;
    } else {
      await _storage.write(key: key, value: value);
    }
  }

  Future<String?> _read(String key) async {
    return volatileMode ? _memoryCache[key] : _storage.read(key: key);
  }

  Future<void> _delete(String key) async {
    if (volatileMode) {
      _memoryCache.remove(key);
    } else {
      await _storage.delete(key: key);
    }
  }

  // ─── Clear All ──────────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    _memoryCache.clear();
    await _storage.deleteAll();
  }
}
