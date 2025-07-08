import 'dart:convert';
import 'dart:io';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:online_doc_savimex/app_import.dart';
import 'package:http/http.dart' as http;

import '../service/secure_storage_service.dart';

class AuthRepository {
  final String _baseUrl = getLocalhost();
  final SecureStorageService _storage = SecureStorageService();

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

  Future<Employee> loginUser({required String employeeID, required String password, required bool rememberMe}) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'em_id': employeeID, 'password': password}),
    );
    if (res.statusCode != 200) throw Exception('Login failed ${res.body}');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final token    = data['token']    as String;
    final empMap   = data['employee'] as Map<String, dynamic>;
    final employee = Employee.fromJson(empMap);

    if(rememberMe){
      await _storage.writeToken(token);
      await _storage.writeEmployee(jsonEncode(empMap));
    }
    else{
      await _storage.deleteToken();
      await _storage.deleteEmployee();
    }

    return employee;
  }

  Future<void> logout() async{
    await _storage.clearAll();
  }

  Future<bool> hasValidToken() async{
    final token = await _storage.readToken();
    if (token == null) return false;
    return !Jwt.isExpired(token);
  }

  Future<Employee?> getPersistedEmployee() async {
    final employeeJson = await _storage.readEmployee();
    if(employeeJson == null) return null;
    final Map<String, dynamic> empMap = jsonDecode(employeeJson) as Map<String, dynamic>;
    return Employee.fromJson(empMap);
  }
}
