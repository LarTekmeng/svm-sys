import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:online_doc_savimex/app_import.dart';

class EmployeeRepository{
  final String _baseUrl = getLocalhost();

  Future<Employee> fetchEmployeeByID(String employeeId) async {
    final uri = (Uri.parse('$_baseUrl/api/employees/$employeeId'));
    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      throw Exception('Failed to load user');
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = (body['employee'] as Map<String, dynamic>?) ?? body;
    return Employee.fromJson(data);
  }
}