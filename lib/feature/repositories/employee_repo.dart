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

  Future<List<Employee>> getAllEmployee() async {
    final uri = Uri.parse('$_baseUrl/api/employees/');
    final resp = await http.get(uri);
    if (resp.statusCode != 200){
      throw Exception('Fail to load employee (status ${resp.statusCode})');
    }
    final List raw = jsonDecode(resp.body) as List;
    return raw.map((e) => Employee.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Employee>> fetchEmployeesByDepartment(int departmentId) async {
    final url = Uri.parse('$_baseUrl/api/employees/$departmentId/');
    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception('Failed to load employees for department');
    }

    final List rawList = jsonDecode(response.body) as List;
    return rawList
        .map((json) => Employee.fromJson(json as Map<String, dynamic>))
        .toList();
  }
 }