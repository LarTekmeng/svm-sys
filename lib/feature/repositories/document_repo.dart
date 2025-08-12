import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:online_doc_savimex/app_import.dart';

class CreateWithFilesResult {
  final Document document;
  final List<DocumentFile> files;
  const CreateWithFilesResult({required this.document, required this.files});
}

class DocumentRepository {
  final String _baseUrl = getLocalhost();

  /// Provide a function that returns the latest access token (e.g., from secure storage).
  /// Using a callback avoids stale tokens if they refresh.
  final String Function()? _tokenProvider;
  DocumentRepository({String Function()? tokenProvider})
      : _tokenProvider = tokenProvider;

  // ---------- internal ----------
  Map<String, String> _headers({bool json = true}) {
    final token = _tokenProvider?.call();
    final h = <String, String>{};
    if (token != null && token.isNotEmpty) h['Authorization'] = 'Bearer $token';
    if (json) h['Content-Type'] = 'application/json';
    return h;
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

  // =========================================================
  //                     DOCUMENTS
  // =========================================================

  /// GET /api/documents
  Future<List<Document>> fetchDocuments() async {
    final uri = Uri.parse('$_baseUrl/api/documents');
    final resp = await http.get(uri, headers: _headers());
    if (resp.statusCode != 200) {
      throw Exception(
          'Failed to load documents (status ${resp.statusCode}): ${resp.body}');
    }
    final List<dynamic> list = jsonDecode(resp.body) as List<dynamic>;
    return list
        .map((e) => Document.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/documents  (JSON only)
  Future<Document> createDocument({
    required int documentTypeId,
    required String title,
    required String description,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/documents');
    final body = jsonEncode({
      'document_type_id': documentTypeId,
      'title': title,
      'description': description,
    });

    final resp = await http.post(uri, headers: _headers(), body: body);
    final decoded = _tryDecode(resp.body);
    if (resp.statusCode != 201) {
      throw Exception(decoded['error'] ??
          'Failed to create document (status ${resp.statusCode})');
    }

    final map = decoded['document'] as Map<String, dynamic>;
    return Document.fromJson(map);
  }

  /// POST /api/documents/with-files  (multipart, register‑style)
  /// fields: document_type_id, title, description
  /// files:  files[]
  Future<CreateWithFilesResult> createDocumentWithFiles({
    required int documentTypeId,
    required String title,
    required String description,
    required List<File> files,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/documents/with-files');
    final token = _tokenProvider?.call();

    final req = http.MultipartRequest('POST', uri);
    if (token != null && token.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $token';
    }
    // DO NOT set Content-Type manually; MultipartRequest sets boundary for us.

    req.fields['document_type_id'] = documentTypeId.toString();
    req.fields['title'] = title;
    req.fields['description'] = description;

    for (final f in files) {
      final fileName = f.path.split(Platform.pathSeparator).last;
      req.files.add(await http.MultipartFile.fromPath('files', f.path,
          filename: fileName));
    }

    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);
    final decoded = _tryDecode(resp.body);

    if (resp.statusCode != 201) {
      throw Exception(decoded['error'] ??
          'Failed to create document with files (status ${resp.statusCode})');
    }

    final docMap = decoded['document'] as Map<String, dynamic>;
    final filesList = (decoded['files'] as List<dynamic>)
        .map((e) => DocumentFile.fromJson(e as Map<String, dynamic>))
        .toList();

    return CreateWithFilesResult(
      document: Document.fromJson(docMap),
      files: filesList,
    );
  }

  // =========================================================
  //                       FILES
  // =========================================================

  /// GET /api/documents/:documentId/files
  Future<List<DocumentFile>> listFiles(int documentId) async {
    final uri = Uri.parse('$_baseUrl/api/documents/$documentId/files');
    final resp = await http.get(uri, headers: _headers());
    if (resp.statusCode != 200) {
      throw Exception(
          'Failed to load files (status ${resp.statusCode}): ${resp.body}');
    }
    final List<dynamic> list = jsonDecode(resp.body) as List<dynamic>;
    return list
        .map((e) => DocumentFile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// DELETE /api/documents/:documentId/files/:fileId
  Future<void> deleteFile({
    required int documentId,
    required int fileId,
  }) async {
    final uri =
    Uri.parse('$_baseUrl/api/documents/$documentId/files/$fileId');
    final resp = await http.delete(uri, headers: _headers());
    if (resp.statusCode != 200) {
      final decoded = _tryDecode(resp.body);
      throw Exception(decoded['error'] ??
          'Failed to delete file (status ${resp.statusCode})');
    }
  }
}
