import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:online_doc_savimex/app_import.dart';

class EmployeeRepository {
  final String baseUrl;
  final http.Client _client;
  final AuthRepository authRepo;

  EmployeeRepository({
    required this.baseUrl,
    http.Client? client,
    required this.authRepo,
  }) : _client = client ?? http.Client();

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

  Future<Map<String, String>> _multipartHeader() async {
    final token = await authRepo.getPersistedToken();
    if (token == null || token.isEmpty) {
      throw const HttpException('No auth token found');
    }
    return {
      HttpHeaders.authorizationHeader: 'Bearer $token',
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

  Future<http.Response> _requestWithRetry(
      String method,
      Uri uri, {
        Map<String, String>? headers,
        Object? body,
      }) async {
    var res = await _client
        .send(http.Request(method, uri)
      ..headers.addAll(headers ?? {})
      ..body = body is String ? body : '')
        .then((streamedRes) => http.Response.fromStream(streamedRes))
        .timeout(const Duration(seconds: 20));

    if (res.statusCode == 401) {
      final ok = await authRepo.hasValidToken();
      if (ok) {
        res = await _client
            .send(http.Request(method, uri)
          ..headers.addAll(await _authOnlyHeader())
          ..body = body is String ? body : '')
            .then((streamedRes) => http.Response.fromStream(streamedRes))
            .timeout(const Duration(seconds: 20));
      }
    }
    return res;
  }

  /* ===============================================
     GET EMPLOYEE BY ID
     =============================================== */
  Future<Employee> fetchEmployeeByID(String employeeId) async {
    final uri = Uri.parse('$baseUrl/api/employees/$employeeId');
    final resp = await _getWithRetry(uri);
    if (resp.statusCode != 200) {
      throw Exception('Failed to load user');
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = (body['employee'] as Map<String, dynamic>?) ?? body;
    return Employee.fromJson(data);
  }

  /* ===============================================
     GET ALL EMPLOYEES
     =============================================== */
  Future<List<Employee>> getAllEmployee() async {
    final uri = Uri.parse('$baseUrl/api/employees/');
    final resp = await _getWithRetry(uri);
    if (resp.statusCode != 200) {
      throw Exception('Fail to load employee (status ${resp.statusCode})');
    }
    final List raw = jsonDecode(resp.body) as List;
    return raw.map((e) => Employee.fromJson(e as Map<String, dynamic>)).toList();
  }

  /* ===============================================
     GET EMPLOYEES BY DEPARTMENT
     =============================================== */
  Future<List<Employee>> fetchEmployeesByDepartment(int departmentId) async {
    final url = Uri.parse('$baseUrl/api/employees/department/$departmentId');
    final response = await _getWithRetry(url);

    if (response.statusCode != 200) {
      throw Exception('Failed to load employees for department');
    }

    final List rawList = jsonDecode(response.body) as List;
    return rawList
        .map((json) => Employee.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /* ===============================================
     UPDATE EMPLOYEE
     =============================================== */
  Future<Employee> updateEmployee({
    required int employeeId,
    required String name,
    required String email,
    String? password,
    required int departmentId,
    required String empId,
    int? roleId,
    File? profileImage,
  }) async {
    final uri = Uri.parse('$baseUrl/api/employees/$employeeId');

    try {
      var request = http.MultipartRequest('PUT', uri);
      request.headers.addAll(await _multipartHeader());

      // Add fields
      request.fields['employee_name'] = name;
      request.fields['email'] = email;
      request.fields['dp_id'] = departmentId.toString();
      request.fields['em_id'] = empId;

      if (roleId != null) {
        request.fields['role_id'] = roleId.toString();
      }

      if (password != null && password.isNotEmpty) {
        request.fields['password'] = password;
      }

      // Add profile image if provided
      if (profileImage != null) {
        final bytes = await profileImage.readAsBytes();
        final multipartFile = http.MultipartFile.fromBytes(
          'profile_image',
          bytes,
          filename: profileImage.path.split('/').last,
        );
        request.files.add(multipartFile);
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 401) {
        // Retry with refreshed token
        final ok = await authRepo.hasValidToken();
        if (ok) {
          request = http.MultipartRequest('PUT', uri);
          request.headers.addAll(await _multipartHeader());
          request.fields.addAll(request.fields);
          if (profileImage != null) {
            final bytes = await profileImage.readAsBytes();
            final multipartFile = http.MultipartFile.fromBytes(
              'profile_image',
              bytes,
              filename: profileImage.path.split('/').last,
            );
            request.files.add(multipartFile);
          }
          final retryResponse = await request.send().timeout(
            const Duration(seconds: 30),
          );
          final finalResponse = await http.Response.fromStream(retryResponse);

          if (finalResponse.statusCode != 200) {
            throw Exception('Failed to update employee: ${finalResponse.body}');
          }

          final body = jsonDecode(finalResponse.body) as Map<String, dynamic>;
          return Employee.fromJson(body['employee'] as Map<String, dynamic>);
        }
      }

      if (response.statusCode != 200) {
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to update employee');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return Employee.fromJson(body['employee'] as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to update employee: $e');
    }
  }

  /* ===============================================
     DELETE EMPLOYEE
     =============================================== */
  Future<void> deleteEmployee(int employeeId) async {
    final uri = Uri.parse('$baseUrl/api/employees/$employeeId');

    final response = await _requestWithRetry(
      'DELETE',
      uri,
      headers: await _authOnlyHeader(),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      final errorBody = jsonDecode(response.body);
      throw Exception(errorBody['error'] ?? 'Failed to delete employee');
    }
  }

  void dispose() => _client.close();
}