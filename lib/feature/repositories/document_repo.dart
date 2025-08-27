import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:online_doc_savimex/app_import.dart';

class CreateWithFilesResult {
  final Document document;
  final List<DocumentFile> files;
  const CreateWithFilesResult({required this.document, required this.files});
}

class DocumentRepository {
  final String baseUrl;
  final AuthRepository authRepo;
  DocumentRepository({required this.baseUrl, required this.authRepo});

  // ───────────────────────── helpers ─────────────────────────

  /// Authorization only (safe for multipart; do NOT set Content-Type here).
  Future<Map<String, String>> _authOnlyHeader() async {
    // Ensure fresh access token (will refresh if needed)
    await authRepo.hasValidToken();
    final token = await authRepo.getPersistedToken();
    if (token != null && token.trim().isNotEmpty) {
      return {'Authorization': 'Bearer ${token.trim()}'};
    }
    return {};
  }

  /// JSON headers (use for GET/POST/PUT/DELETE with JSON body).
  Future<Map<String, String>> _jsonHeaders() async {
    return {
      ...await _authOnlyHeader(),
      'Content-Type': 'application/json', // ✅ correct key
      'Accept': 'application/json',
    };
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

  Future<http.Response> _getWithRetry(Uri uri) async {
    var res = await http.get(uri, headers: await _jsonHeaders());
    if (res.statusCode == 401) {
      await authRepo.hasValidToken();
      res = await http.get(uri, headers: await _jsonHeaders());
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

  /// Multipart POST with 401 retry. We rebuild the request so file streams are fresh.
  Future<http.Response> _postMultipartWithRetry(
      Uri uri, {
        Map<String, String>? fields,
        required List<http.MultipartFile> files,
      }) async {
    Future<http.Response> sendOnce() async {
      final req = http.MultipartRequest('POST', uri);
      req.headers.addAll(await _authOnlyHeader()); // no Content-Type here
      if (fields != null && fields.isNotEmpty) req.fields.addAll(fields);
      req.files.addAll(files);
      final streamed = await req.send();
      return http.Response.fromStream(streamed);
    }

    var res = await sendOnce();
    if (res.statusCode == 401) {
      await authRepo.hasValidToken();
      res = await sendOnce();
    }
    return res;
  }

  // ───────────────────────── API (same signatures) ─────────────────────────

  /// POST /api/documents/with-files  (multipart)
  /// fields: document_type_id, title, description; files: files[]
  Future<CreateWithFilesResult> createDocumentWithFiles({
    required int documentTypeId,
    required String title,
    required String description,
    required List<File> files,
  }) async {
    final uri = Uri.parse('$baseUrl/api/documents/with-files');

    final mpFiles = <http.MultipartFile>[];
    for (final f in files) {
      final name = f.path.split(Platform.pathSeparator).last;
      mpFiles.add(await http.MultipartFile.fromPath('files', f.path, filename: name));
    }

    final res = await _postMultipartWithRetry(
      uri,
      fields: {
        'document_type_id': documentTypeId.toString(),
        'title': title,
        'description': description,
      },
      files: mpFiles,
    );

    final decoded = _tryDecode(res.body);
    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception(decoded['error'] ??
          'Failed to create document with files (status ${res.statusCode})');
    }

    // Support both {document, files} and flat shapes
    final docMap = (decoded['document'] ?? decoded) as Map<String, dynamic>;
    final filesList = ((decoded['files'] ?? []) as List<dynamic>)
        .map((e) => DocumentFile.fromJson(e as Map<String, dynamic>))
        .toList();

    return CreateWithFilesResult(
      document: Document.fromJson(docMap),
      files: filesList,
    );
  }

  /// GET /api/documents/:documentId/files
  Future<List<DocumentFile>> listFiles(int documentId) async {
    final uri = Uri.parse('$baseUrl/api/documents/$documentId/files');
    final res = await _getWithRetry(uri);
    if (res.statusCode != 200) {
      throw Exception('Failed to load files (status ${res.statusCode}): ${res.body}');
    }

    final decoded = _tryDecode(res.body);
    if (decoded['raw'] is List) {
      return (decoded['raw'] as List)
          .cast<Map<String, dynamic>>()
          .map(DocumentFile.fromJson)
          .toList();
    }
    // also accept {files: [...]}
    final list = (decoded['files'] ?? []) as List;
    return list.cast<Map<String, dynamic>>().map(DocumentFile.fromJson).toList();
  }

  /// POST /api/documents/:documentId/files  (multipart)
  Future<List<DocumentFile>> addFiles(
      int documentId,
      List<({String name, List<int> bytes, String mime})> files,
      ) async {
    final uri = Uri.parse('$baseUrl/api/documents/$documentId/files');

    final mpFiles = <http.MultipartFile>[];
    for (final f in files) {
      final mediaType = MediaType.parse(f.mime); // falls back to octet-stream if needed
      mpFiles.add(http.MultipartFile.fromBytes(
        'files',
        f.bytes,
        filename: f.name,
        contentType: mediaType,
      ));
    }

    final res = await _postMultipartWithRetry(uri, files: mpFiles);

    if (res.statusCode != 201 && res.statusCode != 200) {
      final decoded = _tryDecode(res.body);
      throw Exception(decoded['error'] ?? 'Upload failed (status ${res.statusCode})');
    }

    final decoded = _tryDecode(res.body);
    // Accept either a list body or {files:[...]}
    if (decoded['raw'] is List) {
      return (decoded['raw'] as List)
          .cast<Map<String, dynamic>>()
          .map(DocumentFile.fromJson)
          .toList();
    }
    final list = (decoded['files'] ?? []) as List;
    return list.cast<Map<String, dynamic>>().map(DocumentFile.fromJson).toList();
  }

  /// DELETE /api/documents/:documentId/files/:fileId
  Future<void> deleteFile({
    required int documentId,
    required int fileId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/documents/$documentId/files/$fileId');
    final res = await _deleteWithRetry(uri);
    if (res.statusCode != 200 && res.statusCode != 204) {
      final decoded = _tryDecode(res.body);
      throw Exception(decoded['error'] ??
          'Failed to delete file (status ${res.statusCode})');
    }
  }

  /// GET /api/documents/:id/detail
  Future<DocumentDetail> getDetail(int documentId) async {
    final uri = Uri.parse('$baseUrl/api/documents/$documentId/detail');
    var res = await _getWithRetry(uri);

    // Fallback to /api/documents/:id if /detail isn’t available
    if (res.statusCode == 404) {
      final alt = Uri.parse('$baseUrl/api/documents/$documentId');
      res = await _getWithRetry(alt);
    }

    if (res.statusCode != 200) {
      throw Exception('Failed to load detail: ${res.statusCode} ${res.body}');
    }
    return DocumentDetail.fromJson(json.decode(res.body) as Map<String, dynamic>);
  }

  /// POST /api/documents/:id/steps/:stepId/decision
  Future<void> decideStep({
    required int documentId,
    required int stepId,
    required String decision, // 'APPROVED' | 'REJECTED'
  }) async {
    final uri = Uri.parse('$baseUrl/api/documents/$documentId/steps/$stepId/decision');
    final res = await _postJsonWithRetry(uri, {'decision': decision});
    if (res.statusCode != 200) {
      throw Exception('Decision failed: ${res.statusCode} ${res.body}');
    }
  }
}
