import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:online_doc_savimex/app_import.dart';

class HomeView {
  final List<Document> uploadedByMe;
  final List<Document> assignedToMe; // contains Ask-for-Permission + Read-Only
  HomeView({required this.uploadedByMe, required this.assignedToMe});
}

class HomeRepo {
  final String baseUrl;
  final AuthRepository authRepo;
  final http.Client _client;

  HomeRepo({
    required this.baseUrl,
    required this.authRepo,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<HomeView> getView() async {
    final token = await authRepo.getPersistedToken();
    if (token == null || token.isEmpty) {
      throw const HttpException('No auth token found');
    }

    final url = Uri.parse('$baseUrl/api/home/overview');

    final res = await _client.get(
      url,
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer $token',
        HttpHeaders.acceptHeader: 'application/json',
      },
    ).timeout(const Duration(seconds: 20));

    if (res.statusCode != 200) {
      // surface server message if any
      throw HttpException(
        'Failed to fetch home view (${res.statusCode}): ${res.body}',
        uri: url,
      );
    }

    final body = jsonDecode(res.body);
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Unexpected response shape');
    }

    final uploadedRaw = body['uploadedByMe'];
    final assignedRaw = body['assignedToMe'];

    final uploaded = (uploadedRaw is List ? uploadedRaw : const <dynamic>[])
        .map((e) => Document.fromJson(e as Map<String, dynamic>))
        .toList();

    // assignedToMe now includes BOTH action-required and read-only items.
    final assigned = (assignedRaw is List ? assignedRaw : const <dynamic>[])
        .map((e) => Document.fromJson(e as Map<String, dynamic>))
        .toList();

    return HomeView(uploadedByMe: uploaded, assignedToMe: assigned);
  }
}
