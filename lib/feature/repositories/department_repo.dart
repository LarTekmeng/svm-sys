// department_repo.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:online_doc_savimex/app_import.dart';

class DepartmentRepository {
  final String baseUrl;
  DepartmentRepository({required this.baseUrl});

  /// GET /api/departments/all  ->  [{id,name}]
  Future<List<Department>> fetchDepartments() async {
    final url = Uri.parse('$baseUrl/api/departments');
    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw Exception('Failed to load departments (status: ${response.statusCode})');
    }
    final List rawList = jsonDecode(response.body) as List;
    return rawList
        .map((json) => Department.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/departments  ->  {id,name}
  Future<Department> createDepartment(String name) async {
    final url = Uri.parse('$baseUrl/api/departments');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode == 409) {
      throw Exception('Department name already exists');
    }
    if (response.statusCode != 201) {
      throw Exception('Failed to create department (status: ${response.statusCode})');
    }
    final Map<String, dynamic> json = jsonDecode(response.body);
    return Department.fromJson(json);
  }

  Future<Department> updateDepartment(int id, String name) async {
    final url = Uri.parse('$baseUrl/api/departments/$id');
    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode == 409) {
      throw Exception('Department name already exists');
    }
    if (response.statusCode == 404) {
      throw Exception('Department not found');
    }
    if (response.statusCode != 200) {
      throw Exception('Failed to update department (status: ${response.statusCode})');
    }
    final Map<String, dynamic> json = jsonDecode(response.body);
    return Department.fromJson(json);
  }

  Future<void> deleteDepartment(int id) async {
    final url = Uri.parse('$baseUrl/api/departments/$id');
    final response = await http.delete(url);
    if (response.statusCode == 404) {
      throw Exception('Department not found');
    }
    if (response.statusCode != 204) {
      throw Exception('Failed to delete department (status: ${response.statusCode})');
    }
  }
}
