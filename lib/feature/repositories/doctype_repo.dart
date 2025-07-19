import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../app_import.dart';

class DoctypeRepository{

  final String _baseUrl = getLocalhost();
  final AuthRepository _authRepo = AuthRepository.instance;

  /* Create new document type */
  Future<Map<String, dynamic>> newDocType(String title, String description) async {
    final token = await _authRepo.getPersistedToken();
    print('🔑 Persisted token = $token');
    assert(token != null && token.isNotEmpty, 'No JWT in storage!');
    final uri = Uri.parse('$_baseUrl/api/doctypes/add');
    final resp = await http.post(
      uri,
      headers: {'Content-Type' : 'application/json', 'Authorization' : 'Bearer $token'},
      body: jsonEncode({'doc_title': title, 'doc_desc': description}),
    );

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      // success
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } else {
      // non-2xx: throw to be caught in your screen
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
  }
  /*=====*/

  /* List all the document type */
  Future<List<DocumentType>> fetchDocTypes() async {
    final resp = await http.get(Uri.parse('$_baseUrl/api/doctypes/list'));
    if (resp.statusCode != 200) {
      throw Exception('Failed to load document types (status ${resp.statusCode})');
    }
    final List<dynamic> body = jsonDecode(resp.body) as List<dynamic>;
    return body
        .map((e) => DocumentType.fromJson(e as Map<String, dynamic>))
        .toList();
  }
  /*=====*/

  /* Delete document type */
  Future<int> deleteDocType(int id) async {
    final uri  = Uri.parse('$_baseUrl/api/doctypes/$id');
    final resp = await http.delete(uri);

    if (resp.statusCode != 200) {
      throw Exception(
          'Failed to delete document type '
              '(status ${resp.statusCode}): ${resp.body}'
      );
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return body['id'] as int;
  }
  /*=====*/

  /* Update document type */
  Future<int> updateDocType(int id, String title, String description) async {
    final uri  = Uri.parse('$_baseUrl/api/doctypes/$id');
    final resp = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'doc_title':title, 'doc_desc':description})
    );

    if (resp.statusCode != 200) {
      throw Exception(
          'Failed to update document type '
              '(status ${resp.statusCode}): ${resp.body}'
      );
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return body['id'] as int;
  }
  /*=====*/

  /* List all document type of each user that has been create */
  Future<List<DocumentType>> getDoctypeById(String em_id) async {
    final token = await _authRepo.getPersistedToken();
    final uri = Uri.parse('$_baseUrl/api/doctypes/$em_id');
    final resp = await http.get(
        uri,
      headers: {
          'Content-Type' : 'application/json', 'Authorization' : 'Bearer $token',
      },
    );
    if(resp.statusCode != 200){
      print('ERR ${resp.statusCode} : ${resp.body}');
      throw Exception('Failed to load Document Types (status ${resp.statusCode})');
    }
    final List body = jsonDecode(resp.body) as List;
    return body.map((e) => DocumentType.fromJson(e as Map<String, dynamic>)).toList();
  }
  /*=====*/

}