import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:online_doc_savimex/app_import.dart';
import 'package:online_doc_savimex/feature/service/device_info.dart';
import '../service/secure_storage_service.dart';

typedef TokenPair = ({String access, String refresh});

class AuthRepository {
  AuthRepository._(this._dio, this._storage) {
    _installInterceptors();
  }

  static Future<AuthRepository> create() async{

    final baseUrl = await ApiHost.resolve();
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
    ));
    final repo = AuthRepository._(dio, SecureStorageService());
    return repo;
  }
  final Dio _dio;
  final SecureStorageService _storage;

  String? _currentAccessToken;
  String? _currentRefreshToken;

  Future<TokenPair?>? _refreshing; // refresh lock

  Dio get dio => _dio;
  String? get currentAccessToken => _currentAccessToken;
  String? get currentRefreshToken => _currentRefreshToken;

  /// Call once at app start (e.g., in main)
  Future<void> init() async {
    _currentAccessToken  = await _storage.readAccessToken();
    _currentRefreshToken = await _storage.readRefreshToken();

    if (_currentAccessToken != null && _currentAccessToken!.trim().isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer ${_currentAccessToken!}';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }



  // ===== Interceptors =====
  void _installInterceptors() {
    _dio.interceptors.clear();

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final p = options.path;
          final isAuthRoute = p.startsWith('/api/auth/');

          if (isAuthRoute) {
            // Do NOT attach Authorization or refresh for login/register/etc.
            options.headers.remove('Authorization');
            handler.next(options);
            return;
          }

          // Normal flow for protected routes:
          _currentAccessToken  ??= await _storage.readAccessToken();
          _currentRefreshToken ??= await _storage.readRefreshToken();

          if (_currentAccessToken == null || _isExpiringSoon(_currentAccessToken!)) {
            await _ensureFreshToken();
          }

          final at = _currentAccessToken;
          if (at != null && at.trim().isNotEmpty) {
            options.headers['Authorization'] = 'Bearer ${at.trim()}';
          } else {
            options.headers.remove('Authorization');
          }
          handler.next(options);
        },

        onError: (e, handler) async {
          final req = e.requestOptions;

          // Never refresh/retry for /api/auth/*
          if (req.path.startsWith('/api/auth/')) {
            handler.next(e);
            return;
          }

          if (e.response?.statusCode == 401 && req.extra['__retry'] != true) {
            try {
              final pair = await _ensureFreshToken();
              if (pair != null) {
                final opts = Options(
                  method: req.method,
                  headers: Map<String, dynamic>.from(req.headers),
                );
                opts.headers?['Authorization'] = 'Bearer ${pair.access}';
                req.extra['__retry'] = true;

                final response = await _dio.request(
                  req.path,
                  data: req.data,
                  queryParameters: req.queryParameters,
                  options: opts,
                );
                handler.resolve(response);
                return;
              }
            } catch (_) {
              // fall through to logout
            }
            await logout();
          }

          handler.next(e);
        },
      ),
    );
  }


  // ===== Refresh logic =====

  bool _isExpiringSoon(String token, {int seconds = 60}) {
    try {
      final exp = Jwt.getExpiryDate(token);
      if (exp == null) return true;
      final now = DateTime.now().toUtc();
      return exp.toUtc().isBefore(now.add(Duration(seconds: seconds)));
    } catch (_) {
      // Can't decode → treat as expired/malformed
      return true;
    }
  }

  Future<TokenPair?> _ensureFreshToken() async {
    // If another refresh is in flight, await it
    if (_refreshing != null) return await _refreshing;

    // Still valid? Use it
    if (_currentAccessToken != null && !_isExpiringSoon(_currentAccessToken!)) {
      return (access: _currentAccessToken!, refresh: _currentRefreshToken ?? '');
    }

    _currentRefreshToken ??= await _storage.readRefreshToken();
    final rt = _currentRefreshToken;
    if (rt == null || rt.trim().isEmpty || Jwt.isExpired(rt)) return null;

    final c = Completer<TokenPair?>();
    _refreshing = c.future;

    try {
      // Use a bare Dio client to avoid re-entering interceptors
      final bare = Dio(BaseOptions(baseUrl: _dio.options.baseUrl));
      final res = await bare.post('/api/auth/refresh', data: {'refreshToken': rt});
      if (res.statusCode != 200) {
        c.complete(null);
        return null;
      }

      final map  = res.data as Map<String, dynamic>;
      final newA = (map['accessToken'] ?? map['access_token'])?.toString();
      final newR = (map['refreshToken'] ?? map['refresh_token'])?.toString();

      if (newA == null || newA.isEmpty) {
        c.complete(null);
        return null;
      }

      _currentAccessToken  = newA;
      _currentRefreshToken = (newR == null || newR.isEmpty) ? rt : newR;

      await _storage.writeAccessToken(_currentAccessToken!);
      await _storage.writeRefreshToken(_currentRefreshToken!);

      // Prime header for subsequent requests
      _dio.options.headers['Authorization'] = 'Bearer ${_currentAccessToken!}';

      final pair = (access: _currentAccessToken!, refresh: _currentRefreshToken!);
      c.complete(pair);
      return pair;
    } catch (err) {
      c.complete(null);
      rethrow;
    } finally {
      _refreshing = null;
    }
  }

  // ===== Public API =====

  /// Registration (kept as-is; FormData auto-sets multipart Content-Type)
  Future<void> registerEmployee({
    required String name,
    required String email,
    required String password,
    required int departmentID,
    required String employeeID,
    int? roleId,
    File? profileImage,
  }) async {
    final form = FormData.fromMap({
      'employee_name': name,
      'email': email,
      'password': password,
      'dp_id': departmentID.toString(),
      'em_id': employeeID,
      'role_id': roleId,
      if (profileImage != null)
        'profile_image': await MultipartFile.fromFile(
          profileImage.path,
          filename: profileImage.path.split(Platform.pathSeparator).last,
        ),
    });

    final resp = await _dio.post('/api/auth/register', data: form);
    if (resp.statusCode != 201) {
      throw DioException(
        requestOptions: resp.requestOptions,
        response: resp,
        error: 'Register failed',
        type: DioExceptionType.badResponse,
      );
    }
  }

  /// Login → persist + cache + prime Authorization header
  Future<Employee> loginUser({
    required String employeeID,
    required String password,
    required bool rememberMe,
  }) async {
    // Ensure NO Authorization header is sent
    final resp = await _dio.post(
      '/api/auth/login',
      data: {
        'em_id': employeeID.trim(),    // trim input
        'password': password,          // do NOT trim password
        'rememberMe': rememberMe,
      },
      options: Options(
        validateStatus: (s) => true,   // we handle 4xx ourselves
        headers: {'Authorization': null},
      ),
    );

    if (resp.statusCode == 401) {
      // Pull a useful message from server if present
      final msg = (resp.data is Map && (resp.data as Map)['message'] != null)
          ? (resp.data as Map)['message'].toString()
          : 'Invalid ID or password';
      throw AuthFailure(msg);
    }

    if (resp.statusCode != 200) {
      final msg = (resp.data is Map && (resp.data as Map)['message'] != null)
          ? (resp.data as Map)['message'].toString()
          : 'Login failed (HTTP ${resp.statusCode})';
      throw AuthFailure(msg);
    }

    final data = resp.data as Map<String, dynamic>;
    final accessToken  = (data['accessToken'] ?? data['access_token']) as String;
    final refreshToken = (data['refreshToken'] ?? data['refresh_token']) as String;
    final empMap       = data['employee'] as Map<String, dynamic>;
    final employee     = Employee.fromJson(empMap);

    await _storage.writeAccessToken(accessToken);
    await _storage.writeRefreshToken(refreshToken);
    await _storage.writeEmployee(jsonEncode(empMap));
    await _storage.writeRememberMe(rememberMe);

    _currentAccessToken  = accessToken;
    _currentRefreshToken = refreshToken;
    _dio.options.headers['Authorization'] = 'Bearer $accessToken';

    return employee;
  }

  Future<void> logout() async {
    _currentAccessToken = null;
    _currentRefreshToken = null;
    _dio.options.headers.remove('Authorization');
    await Future.wait([
      _storage.deleteAccessToken(),
      _storage.deleteRefreshToken(),
      _storage.deleteEmployee(),
      _storage.deleteRememberMe(),
    ]);
  }

  // ===== Convenience (compatibility with your existing code) =====

  Future<Employee?> getPersistedEmployee() async {
    final jsonStr = await _storage.readEmployee();
    if (jsonStr == null) return null;
    return Employee.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
  }

  Future<String?> getPersistedToken() async {
    return _currentAccessToken ?? await _storage.readAccessToken();
  }

  Future<bool> getRememberMeFlag() async {
    final v = await _storage.readRememberMe();
    return v;
  }

  /// Optional: quick gate for screens
  Future<bool> hasValidToken() async {
    _currentAccessToken  ??= await _storage.readAccessToken();
    _currentRefreshToken ??= await _storage.readRefreshToken();
    if (_currentAccessToken != null && !_isExpiringSoon(_currentAccessToken!, seconds: 5)) {
      return true;
    }
    final p = await _ensureFreshToken();
    return p != null;
  }
}
