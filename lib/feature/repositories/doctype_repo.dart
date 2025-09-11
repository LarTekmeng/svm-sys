import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../app_import.dart';
import '../service/device_info.dart';

class DoctypeRepository {
  final String baseUrl;
  final AuthRepository authRepo;
  final DepartmentRepository deptRepo;
  final EmployeeRepository empRepo;
  DoctypeRepository({required this.baseUrl, required this.authRepo, required this.empRepo, required this.deptRepo});

  // ───────────────────────── helpers: headers + retry ─────────────────────────

  /// Authorization header only (safe for any method; don't add Content-Type here).
  Future<Map<String, String>> _authOnlyHeader() async {
    // Ensure we have a fresh access token; will refresh if needed
    await authRepo.hasValidToken();
    final token = await authRepo.getPersistedToken();
    if (token != null && token.trim().isNotEmpty) {
      return {'Authorization': 'Bearer ${token.trim()}'};
    }
    return {};
  }

  /// JSON headers (use for POST/PUT/DELETE with JSON body).
  Future<Map<String, String>> _jsonHeaders() async {
    return {
      ...await _authOnlyHeader(),
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  Future<http.Response> _getWithRetry(Uri uri) async {
    var res = await http.get(uri, headers: {
      ...await _authOnlyHeader(),
      'Accept': 'application/json',
    });
    if (res.statusCode == 401) {
      await authRepo.hasValidToken();
      res = await http.get(uri, headers: {
        ...await _authOnlyHeader(),
        'Accept': 'application/json',
      });
    }
    return res;
  }

  Future<http.Response> _postJsonWithRetry(Uri uri, Map<String, dynamic> body) async {
    var res = await http.post(uri, headers: await _jsonHeaders(), body: jsonEncode(body));
    if (res.statusCode == 401) {
      await authRepo.hasValidToken();
      res = await http.post(uri, headers: await _jsonHeaders(), body: jsonEncode(body));
    }
    return res;
  }

  Future<http.Response> _putJsonWithRetry(Uri uri, Map<String, dynamic> body) async {
    var res = await http.put(uri, headers: await _jsonHeaders(), body: jsonEncode(body));
    if (res.statusCode == 401) {
      await authRepo.hasValidToken();
      res = await http.put(uri, headers: await _jsonHeaders(), body: jsonEncode(body));
    }
    return res;
  }

  Future<http.Response> _deleteWithRetry(Uri uri) async {
    var res = await http.delete(uri, headers: await _jsonHeaders());
    if (res.statusCode == 401) {
      await authRepo.hasValidToken();
      res = await http.delete(uri, headers: await _jsonHeaders());
    }
    return res;
  }

  Map<String, dynamic> _tryDecode(String body) {
    try {
      final v = jsonDecode(body);
      if (v is Map<String, dynamic>) return v;
      return {'raw': v};
    } catch (_) {
      return {'raw': body};
    }
  }

  // ───────────────────────── API (unchanged signatures) ─────────────────────────

  /* Create new document type */
  Future<Map<String, dynamic>> newDocType(String title, String description) async {
    final uri = Uri.parse('$baseUrl/api/doctypes/add');
    final resp = await _postJsonWithRetry(uri, {'title': title, 'description': description});

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
  }

  /* Delete document type */
  Future<int> deleteDocType(int id) async {
    final uri = Uri.parse('$baseUrl/api/doctypes/$id');
    final resp = await _deleteWithRetry(uri);

    if (resp.statusCode != 200 && resp.statusCode != 204) {
      throw Exception('Failed to delete document type (status ${resp.statusCode}): ${resp.body}');
    }

    // Support various success shapes
    if (resp.body.isEmpty) return id; // 204
    final map = _tryDecode(resp.body);
    if (map.containsKey('id')) return map['id'] as int;
    if (map.containsKey('data') && map['data'] is Map && (map['data'] as Map).containsKey('id')) {
      return (map['data']['id'] as num).toInt();
    }
    // Fallback: return the id we deleted
    return id;
  }

  /* Update document type */
  Future<int> updateDocType(int id, String title, String description) async {
    final uri = Uri.parse('$baseUrl/api/doctypes/$id');
    final resp = await _putJsonWithRetry(uri, {'title': title, 'description': description});

    if (resp.statusCode != 200) {
      throw Exception('Failed to update document type (status ${resp.statusCode}): ${resp.body}');
    }

    final map = _tryDecode(resp.body);
    if (map.containsKey('id')) return (map['id'] as num).toInt();
    if (map.containsKey('data') && map['data'] is Map && (map['data'] as Map).containsKey('id')) {
      return (map['data']['id'] as num).toInt();
    }
    return id;
  }

  /* List all document type of each user that has been create */
  Future<List<DocumentType>> getDoctypeById(String id) async {
    final uri = Uri.parse('$baseUrl/api/doctypes/$id');
    final resp = await _getWithRetry(uri);

    if (resp.statusCode != 200) {
      throw Exception('Failed to load Document Types (status ${resp.statusCode}): ${resp.body}');
    }

    // Accept both a raw list and {items: [...]}
    final decoded = _tryDecode(resp.body);
    if (decoded['raw'] is List) {
      return (decoded['raw'] as List)
          .cast<Map<String, dynamic>>()
          .map((e) => DocumentType.fromJson(e))
          .toList();
    }

    final items = (decoded['items'] ?? decoded['data'] ?? []) as List;
    return items
        .cast<Map<String, dynamic>>()
        .map((e) => DocumentType.fromJson(e))
        .toList();
  }

  /* Department / Employee passthroughs (unchanged) */
  Future<List<Department>> getDepartment() async => deptRepo.fetchDepartments();
  Future<List<Employee>> getEmployee() async => empRepo.getAllEmployee();

  /* Set/replace doctype flow */
  Future<void> setDocTypeFlow(
      int documentTypeId,
      String action,
      String forwardMode,
      List<Map<String, dynamic>> flows,
      ) async {
    final uri = Uri.parse('$baseUrl/api/doctypes/$documentTypeId/flow');

    final payload = <String, dynamic>{
      'action': action,
      'forward_mode': forwardMode,
      'flows': flows,
    };

    final resp = await _putJsonWithRetry(uri, payload);
    if (resp.statusCode != 200) {
       throw Exception('Failed to set flow (status ${resp.statusCode}): ${resp.body}');
    }
  }

  Future<Map<String, dynamic>> fetchDocTypeFlow(int documentTypeId) async{
    final uri = Uri.parse('$baseUrl/api/doctypes/$documentTypeId/flow');
    final resp = await _getWithRetry(uri);
    if(resp.statusCode != 200){
      throw Exception('Failed to load flow (status ${resp.statusCode}): ${resp.body}');
    }
    final map = _tryDecode(resp.body);
    if(map['data'] is Map<String, dynamic>) {
      return Map<String, dynamic>.from(map);
    }
    return Map<String, dynamic>.from(map);
  }
}
