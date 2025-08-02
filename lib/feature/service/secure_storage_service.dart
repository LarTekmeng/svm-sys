import 'package:online_doc_savimex/app_import.dart';

class SecureStorageService {
  static const _accessTokenKey  = 'ACCESS_TOKEN';
  static const _refreshTokenKey = 'REFRESH_TOKEN';
  static const _employeeKey     = 'EMPLOYEE_JSON';
  static const _rememberMeKey   = 'REMEMBER_ME';

  bool volatileMode = false;
  final Map<String, String> _memoryCache = {};
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // ─── Generic helpers ────────────────────────────────────────────────────────

  Future<void> _write(String key, String value) async {
    if (volatileMode) {
      _memoryCache[key] = value;
    } else {
      await _storage.write(key: key, value: value);
    }
  }

  Future<String?> _read(String key) async {
    return volatileMode
        ? _memoryCache[key]
        : _storage.read(key: key);
  }

  Future<void> _delete(String key) async {
    if (volatileMode) {
      _memoryCache.remove(key);
    } else {
      await _storage.delete(key: key);
    }
  }

  // ─── Access Token ───────────────────────────────────────────────────────────

  Future<void> writeAccessToken(String token) =>
      _write(_accessTokenKey, token);

  Future<String?> readAccessToken() =>
      _read(_accessTokenKey);

  Future<void> deleteAccessToken() =>
      _delete(_accessTokenKey);

  // ─── Refresh Token ──────────────────────────────────────────────────────────

  Future<void> writeRefreshToken(String token) =>
      _write(_refreshTokenKey, token);

  Future<String?> readRefreshToken() =>
      _read(_refreshTokenKey);

  Future<void> deleteRefreshToken() =>
      _delete(_refreshTokenKey);

  // ─── Employee JSON ──────────────────────────────────────────────────────────

  Future<void> writeEmployee(String json) =>
      _write(_employeeKey, json);

  Future<String?> readEmployee() =>
      _read(_employeeKey);

  Future<void> deleteEmployee() =>
      _delete(_employeeKey);

  // ─── REMEMBER ME ─────────────────────────────────────────────────────────────

  Future<void> writeRememberMe(bool rememberMe) =>
      _write(_rememberMeKey, rememberMe.toString());

  Future<bool> readRememberMe() async {
    final v = await _read(_rememberMeKey);
    return v == 'true';
  }

  Future<void> deleteRememberMe() =>
      _delete(_rememberMeKey);

  // ─── Clear All ──────────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    _memoryCache.clear();
    await _storage.deleteAll();
  }
}
