import 'dart:convert';
import 'package:online_doc_savimex/app_import.dart';
import 'package:http/http.dart' as http;



class AuthRepository{

  final String _baseUrl = getLocalhost();

  Future<Employee> registerEmployee(String name, String email, String password, int departmentID, String employeeID) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'employee_name' : name, 'email' : email, 'password' : password, 'dp_id' : departmentID, 'em_id' : employeeID}),
    );
    if(resp.statusCode == 201){
      if(resp.body.isEmpty){
        throw Exception('Empty response from server');
      }
    }
    final Map<String, dynamic> body = jsonDecode(resp.body);
    if (resp.statusCode != 201) {
      throw Exception(body['error'] ?? 'Fail to Register');
    }
    final employeeJson = body['employee'] as Map<String, dynamic>;
    return Employee.fromJson(employeeJson);
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