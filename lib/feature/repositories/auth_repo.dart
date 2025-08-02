import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:online_doc_savimex/app_import.dart';

import '../service/secure_storage_service.dart';

class AuthRepository {
  final Dio _dio;
  final SecureStorageService _storage;

  String? _currentAccessToken;
  String? _currentRefreshToken;

  AuthRepository._(this._dio, this._storage) {
    // Load tokens into memory and set the Authorization header
    init();
    // Attach an interceptor to always inject the latest access token
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = _currentAccessToken ?? await _storage.readAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  static final AuthRepository instance = AuthRepository._(
    Dio(BaseOptions(
      baseUrl: getLocalhost(),
      connectTimeout: Duration(milliseconds: 5000),
      receiveTimeout: Duration(milliseconds: 5000),
      headers: {'Content-Type': 'application/json'},
    )),
    SecureStorageService(),
  );

  /// Read persisted tokens into memory and prime Dio’s header
  Future<void> init() async {
    final at = await _storage.readAccessToken();
    final rt = await _storage.readRefreshToken();
    if (at != null) {
      _currentAccessToken = at;
      _dio.options.headers['Authorization'] = 'Bearer $at';
    }
    if (rt != null) _currentRefreshToken = rt;
  }

  /// 1) Register (with optional image upload)
  Future<void> registerEmployee({
    required String name,
    required String email,
    required String password,
    required int departmentID,
    required String employeeID,
    File? profileImage,
  }) async {
    final form = FormData.fromMap({
      'employee_name': name,
      'email': email,
      'password': password,
      'dp_id': departmentID.toString(),
      'em_id': employeeID,
      if (profileImage != null)
        'profile_image': await MultipartFile.fromFile(
          profileImage.path,
          filename: profileImage.path.split(Platform.pathSeparator).last,
        ),
    });

    final resp = await _dio.post('/api/auth/register', data: form);
    if (resp.statusCode != 201) {
      throw Exception('Register failed: ${resp.statusCode} ${resp.data}');
    }
  }

  /// 2) Login and persist tokens + user
  Future<Employee> loginUser({
    required String employeeID,
    required String password,
    required bool rememberMe,
  }) async {
    final resp = await _dio.post(
      '/api/auth/login',
      data: {
        'em_id': employeeID,
        'password': password,
        'rememberMe': rememberMe,
      },
    );

    if (resp.statusCode != 200) {
      throw Exception('Login failed: ${resp.statusCode} ${resp.data}');
    }

    final data = resp.data as Map<String, dynamic>;
    final accessToken  = data['accessToken']  as String;
    final refreshToken = data['refreshToken'] as String;
    final empMap       = data['employee']     as Map<String, dynamic>;
    final employee     = Employee.fromJson(empMap);

    // Persist
    await _storage.writeAccessToken(accessToken);
    await _storage.writeRefreshToken(refreshToken);
    await _storage.writeEmployee(jsonEncode(empMap));
    await _storage.writeRememberMe(rememberMe);

    // Cache in-memory
    _currentAccessToken  = accessToken;
    _currentRefreshToken = refreshToken;
    _dio.options.headers['Authorization'] = 'Bearer $accessToken';

    return employee;
  }

  /// 3) Logout
  Future<void> logout() async {
    _currentAccessToken = null;
    _currentRefreshToken = null;
    await Future.wait([
      _storage.deleteAccessToken(),
      _storage.deleteRefreshToken(),
      _storage.deleteEmployee(),
      _storage.deleteRememberMe(),
    ]);
  }

  /// 4) Check expiry & refresh if needed
  Future<bool> hasValidToken() async {
    final at = _currentAccessToken ?? await _storage.readAccessToken();
    if (at != null && !Jwt.isExpired(at)) {
      return true;
    }

    // Try refresh
    final rt = _currentRefreshToken ?? await _storage.readRefreshToken();
    if (rt == null || Jwt.isExpired(rt)) return false;

    try {
      final resp = await _dio.post(
        '/api/auth/refresh',
        data: {'refreshToken': rt},
      );

      if (resp.statusCode != 200) return false;
      final data = resp.data as Map<String, dynamic>;
      final newAT = data['accessToken']  as String;
      final newRT = data['refreshToken'] as String;

      // Persist new tokens
      await _storage.writeAccessToken(newAT);
      await _storage.writeRefreshToken(newRT);

      // Update memory & header
      _currentAccessToken  = newAT;
      _currentRefreshToken = newRT;
      _dio.options.headers['Authorization'] = 'Bearer $newAT';
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Helpers to read persisted user/token
  Future<Employee?> getPersistedEmployee() async {
    final jsonStr = await _storage.readEmployee();
    if (jsonStr == null) return null;
    final Map<String, dynamic> empMap = jsonDecode(jsonStr);
    return Employee.fromJson(empMap);
  }

  Future<String?> getPersistedToken() async {
    return _currentAccessToken ?? await _storage.readAccessToken();
  }

  Future<bool> getRememberMeFlag() async {
    return (await _storage.readRememberMe()) == 'true';
  }
}
