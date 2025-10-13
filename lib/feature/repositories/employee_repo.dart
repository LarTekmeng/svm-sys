import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:online_doc_savimex/app_import.dart';

class EmployeeRepository{
  final String baseUrl;
  final http.Client _client;
  final AuthRepository authRepo;

  EmployeeRepository({required this.baseUrl, http.Client? client, required this.authRepo}) : _client = client ?? http.Client();

  Future<Map<String, String>> _authOnlyHeader() async {
    final token = await authRepo.getPersistedToken();
    if (token == null || token.isEmpty) {
      throw const HttpException('No auth token found');
    }
    return {
      HttpHeaders.authorizationHeader: 'Bearer $token',
      HttpHeaders.acceptHeader: 'application/json',
    };
  }

  Future<http.Response> _getWithRetry(Uri uri) async {
    var res = await _client
        .get(uri, headers: await _authOnlyHeader())
        .timeout(const Duration(seconds: 20));

    if (res.statusCode == 401) {
      final ok = await authRepo.hasValidToken(); // triggers refresh if needed
      if (ok) {
        res = await _client
            .get(uri, headers: await _authOnlyHeader())
            .timeout(const Duration(seconds: 20));
      }
    }
    return res;
  }

  Future<Employee> fetchEmployeeByID(String employeeId) async {
    final uri = (Uri.parse('$baseUrl/api/employees/$employeeId'));
    final resp = await _getWithRetry(uri);
    if (resp.statusCode != 200) {
      throw Exception('Failed to load user');
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = (body['employee'] as Map<String, dynamic>?) ?? body;
    return Employee.fromJson(data);
  }

  Future<List<Employee>> getAllEmployee() async {
    final uri = Uri.parse('$baseUrl/api/employees/');
    final resp = await _getWithRetry(uri);
    if (resp.statusCode != 200){
      throw Exception('Fail to load employee (status ${resp.statusCode})');
    }
    final List raw = jsonDecode(resp.body) as List;
    return raw.map((e) => Employee.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Employee>> fetchEmployeesByDepartment(int departmentId) async {
    final url = Uri.parse('$baseUrl/api/employees/$departmentId/');
    final response = await _getWithRetry(url);

    if (response.statusCode != 200) {
      throw Exception('Failed to load employees for department');
    }

    final List rawList = jsonDecode(response.body) as List;
    return rawList
        .map((json) => Employee.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  void dispose() => _client.close();
 }