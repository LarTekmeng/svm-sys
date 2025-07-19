import 'dart:convert';
import 'dart:io';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:online_doc_savimex/app_import.dart';
import 'package:http/http.dart' as http;

import '../service/secure_storage_service.dart';

class AuthRepository {
  final String _baseUrl = getLocalhost();
  final SecureStorageService _storage = SecureStorageService();
  AuthRepository._();
  static final AuthRepository instance = AuthRepository._();

  String? _currentAccessToken;
  String? _currentRefreshToken;

  Future<void> registerEmployee(
    String name,
    String email,
    String password,
    int departmentID,
    String employeeID, {
    File? profileImage,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/auth/register');
    final req = http.MultipartRequest('POST', uri)
    ..fields['employee_name'] = name
    ..fields['email']         = email
    ..fields['password']      = password.toString()
    ..fields['dp_id']         = departmentID.toString()
    ..fields['em_id']         = employeeID;
    if(profileImage != null){
      req.files.add(await http.MultipartFile.fromPath('profile_image', profileImage.path));
    }
    final resp = await req.send();
    if (resp.statusCode != 201) {
      final body = await resp.stream.bytesToString();
      throw Exception('Register failed: $body');
    }
  }

  Future<void> init() async {
    final at = await _storage.readAccessToken();
    if (at != null) _currentAccessToken = at;
    final rt = await _storage.readRefreshToken();
    if (rt != null) _currentRefreshToken = rt;
  }

  Future<Employee> loginUser({
    required String employeeID,
    required String password,
    required bool rememberMe,
  }) async {
    // 1) Call your API
    final res = await http.post(
      Uri.parse('$_baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'em_id': employeeID,
        'password': password,
        'rememberMe': rememberMe,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Login failed: ${res.body}');
    }

    // 2) Parse response
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final accessToken  = data['accessToken']  as String;
    final refreshToken = data['refreshToken'] as String;
    final empMap       = data['employee']     as Map<String, dynamic>;
    final employee     = Employee.fromJson(empMap);

    // 3) If not remembering, switch to volatile (in-memory) storage
    if (!rememberMe) {
      _storage.volatileMode = true;
    }

    // 4) Persist everything exactly once
    await _storage.writeAccessToken(accessToken);
    await _storage.writeRefreshToken(refreshToken);
    await _storage.writeEmployee(jsonEncode(empMap));
    await _storage.writeRememberMe(rememberMe);

    // 5) Cache in-memory for immediate use
    _currentAccessToken  = accessToken;
    _currentRefreshToken = refreshToken;

    return employee;
  }


  Future<void> logout() async{
    _currentAccessToken = null;
    _currentRefreshToken = null;
    await _storage.deleteAccessToken();
    await _storage.deleteRefreshToken();
    await _storage.deleteRememberMe();
    await _storage.deleteEmployee();
  }

  Future<bool> hasValidToken() async {
    debugPrint('🔍 Checking access token...');
    final at = await _storage.readAccessToken();

    if (at == null) {
      debugPrint('⚠️ No access token found');
    } else {
      final expired = Jwt.isExpired(at);
      debugPrint('📦 Access token: $at');
      debugPrint('⌛ Expired? $expired');
      if (!expired) {
        debugPrint('✅ Access token is valid.');
        return true;
      }
    }

    debugPrint('🔄 Trying refresh token...');
    final rt = await _storage.readRefreshToken();
    if (rt == null) {
      debugPrint('❌ Refresh token missing');
      return false;
    }

    if (Jwt.isExpired(rt)) {
      debugPrint('⛔ Refresh token expired');
      return false;
    }

    final res = await http.post(
      Uri.parse('$_baseUrl/api/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({ 'refreshToken': rt }),
    );

    debugPrint('🔁 Refresh status: ${res.statusCode}');
    if (res.statusCode != 200 || res.body.isEmpty) return false;

    try {
      final data = jsonDecode(res.body);
      debugPrint('🔐 New access token: ${data['accessToken']}');
      await _storage.writeAccessToken(data['accessToken']);
      await _storage.writeRefreshToken(data['refreshToken']);
      debugPrint('✅ Tokens refreshed successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to decode refresh response: $e');
      return false;
    }
  }

  Future<Employee?> getPersistedEmployee() async {
    final employeeJson = await _storage.readEmployee();
    if(employeeJson == null) return null;
    final Map<String, dynamic> empMap = jsonDecode(employeeJson) as Map<String, dynamic>;
    return Employee.fromJson(empMap);
  }

  Future<String?> getPersistedToken() async {
    if (_currentAccessToken != null) return _currentAccessToken;
    return await _storage.readAccessToken();
  }

  Future<bool> getRememberMeFlag() async {
    final remember = await _storage.readRememberMe();
    return remember == 'true';
  }

}
