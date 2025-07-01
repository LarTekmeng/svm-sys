import 'dart:convert';
import 'dart:io';
import 'package:online_doc_savimex/app_import.dart';
import 'package:http/http.dart' as http;

class AuthRepository {
  final String _baseUrl = getLocalhost();

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

  Future<Employee> loginUser(String employeeID, String password) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'em_id': employeeID, 'password': password}),
    );
    print('Status: ${resp.statusCode}');
    print('Body: ${resp.body}');
    final Map<String, dynamic> body = jsonDecode(resp.body);
    if (resp.statusCode != 200 || body['message'] != 'Login successful') {
      throw Exception(body['error'] ?? 'Login failed');
    }
    // your API wraps the user under `user`
    final employeeJson = body['employee'] as Map<String, dynamic>;
    return Employee.fromJson(employeeJson);
  }
}
