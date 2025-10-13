// lib/data/repo/profile_repo.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:online_doc_savimex/app_import.dart';

class ProfileRepo {
  final String baseUrl;
  final AuthRepository authRepo;
  final http.Client _client;

  ProfileRepo(
      {
        required this.baseUrl,
        required this.authRepo,
        http.Client ? client,
      }) : _client = client ?? http.Client();

  /// Build auth headers using the persisted token (used by all calls).
  Future<Map<String, String>> _authOnlyHeader() async {
    final token = await authRepo.getPersistedToken(); // persisted when Remember Me is on
    if (token == null || token.isEmpty) {
      throw const HttpException('No auth token found');
    }
    return {
      HttpHeaders.authorizationHeader: 'Bearer $token',
      HttpHeaders.acceptHeader: 'application/json',
    };
  }

  /// PATCH (JSON) with 401 auto-refresh retry.
  Future<http.Response> _patchJsonWithRetry(Uri uri, Map<String, dynamic> body) async {
    var res = await _client
        .patch(uri,
        headers: {
          ...(await _authOnlyHeader()),
          HttpHeaders.contentTypeHeader: 'application/json',
        },
        body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));

    if (res.statusCode == 401) {
      final ok = await authRepo.hasValidToken(); // triggers refresh if needed
      if (ok) {
        res = await _client
            .patch(uri,
            headers: {
              ...(await _authOnlyHeader()),
              HttpHeaders.contentTypeHeader: 'application/json',
            },
            body: jsonEncode(body))
            .timeout(const Duration(seconds: 20));
      }
    }
    return res;
  }

  /// Multipart PATCH with 401 auto-refresh retry.
  Future<http.Response> _multipartPatchWithRetry(
      Uri uri, {
        Map<String, String>? fields,
        List<http.MultipartFile> files = const [],
      }) async {
    Future<http.Response> _sendOnce() async {
      final req = http.MultipartRequest('PATCH', uri);
      req.headers.addAll(await _authOnlyHeader());
      if (fields != null) req.fields.addAll(fields);
      for (final f in files) {
        req.files.add(f);
      }
      final streamed = await req.send();
      return http.Response.fromStream(streamed);
    }

    var res = await _sendOnce();

    if (res.statusCode == 401) {
      final ok = await authRepo.hasValidToken(); // triggers refresh if needed
      if (ok) {
        res = await _sendOnce();
      }
    }
    return res;
  }

  /// Update profile (image/name/email/department). Password is a separate API.
  Future<Map<String, dynamic>> updateProfile({
    String? employeeName,
    String? email,
    int? departmentId,
    File? avatarFile,
  }) async {
    final uri = Uri.parse('$baseUrl/api/me');

    if (avatarFile != null) {
      final resp = await _multipartPatchWithRetry(
        uri,
        fields: {
          if (employeeName != null) 'employee_name': employeeName,
          if (email != null) 'email': email,
          if (departmentId != null) 'department_id': departmentId.toString(),
        },
        files: [
          await http.MultipartFile.fromPath('avatar', avatarFile.path),
        ],
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      throw Exception('Update profile failed: ${resp.statusCode} ${resp.body}');
    } else {
      final body = <String, dynamic>{
        if (employeeName != null) 'employee_name': employeeName,
        if (email != null) 'email': email,
        if (departmentId != null) 'department_id': departmentId,
      };

      final resp = await _patchJsonWithRetry(uri, body);
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      throw Exception('Update profile failed: ${resp.statusCode} ${resp.body}');
    }
  }

  /// Change password (current + new). Separate from profile.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final uri = Uri.parse('$baseUrl/api/me/password');
    final resp = await _patchJsonWithRetry(uri, {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Change password failed: ${resp.statusCode} ${resp.body}');
    }
  }

  Future<Employee> getMe() async {
    final headers = await _authOnlyHeader();
    final uri = Uri.parse('$baseUrl/api/me');

    final resp = await _client.get(uri, headers: headers)
        .timeout(const Duration(seconds: 20));

    if (resp.statusCode != 200) {
      throw Exception('Failed to load profile: ${resp.statusCode} ${resp.body}');
    }
    final map = jsonDecode(resp.body) as Map<String, dynamic>;
    return Employee.fromJson(map);
  }
}
