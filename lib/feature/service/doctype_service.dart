import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:online_doc_savimex/app_import.dart';

String _baseUrl = getLocalhost();

Future<Map<String, dynamic>> newDocType(String title, String description,) async {
  final uri = Uri.parse('$_baseUrl/api/doctypes/add');
  final resp = await http.post(
    uri,
    headers: {'Content-Type': 'application/json'},
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