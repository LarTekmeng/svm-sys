import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_client_sse/constants/sse_request_type_enum.dart';
import 'package:flutter_client_sse/flutter_client_sse.dart';
import 'package:http/http.dart' as http;
import 'package:online_doc_savimex/app_import.dart';

class HomeView {
  final List<Document> uploadedByMe;
  final List<Document> assignedToMe; // Ask-for-Permission + Read-Only
  HomeView({required this.uploadedByMe, required this.assignedToMe});
}

class HomeRepo {
  final String baseUrl;
  final AuthRepository authRepo;
  final http.Client _client;

  StreamSubscription<SSEModel>? _esSub;
  final _realtime = StreamController<void>.broadcast();
  Stream<void> get realtime => _realtime.stream;

  bool _disposed = false;
  Timer? _retryTimer;
  bool get _connected => _esSub != null;

  HomeRepo({
    required this.baseUrl,
    required this.authRepo,
    http.Client? client,
  }) : _client = client ?? http.Client();

  // ───────────────────────── helpers: headers + retry ─────────────────────────

  /// Authorization header only (no Content-Type here).
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

  /// JSON headers (for endpoints returning/expecting JSON).
  Future<Map<String, String>> _jsonHeaders() async {
    final h = await _authOnlyHeader();
    return {
      ...h,
      HttpHeaders.contentTypeHeader: 'application/json',
    };
  }

  /// GET with one auto-refresh retry (same as DoctypeRepository style).
  Future<http.Response> _getWithRetry(Uri uri) async {
    var res = await _client
        .get(uri, headers: await _authOnlyHeader())
        .timeout(const Duration(seconds: 20));

    if (res.statusCode == 401) {
      // Will refresh tokens (and persist) when Remember Me is enabled.
      final ok = await authRepo.hasValidToken(); // triggers refresh if needed
      if (ok) {
        res = await _client
            .get(uri, headers: await _authOnlyHeader())
            .timeout(const Duration(seconds: 20));
      }
    }
    return res;
  }

  // ───────────────────────── REST API ─────────────────────────

  Future<HomeView> getView() async {
    final uri = Uri.parse('$baseUrl/api/home/overview');
    final res = await _getWithRetry(uri);

    if (res.statusCode != 200) {
      throw HttpException(
        'Failed to fetch home view (${res.statusCode}): ${res.body}',
        uri: uri,
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

    final assigned = (assignedRaw is List ? assignedRaw : const <dynamic>[])
        .map((e) => Document.fromJson(e as Map<String, dynamic>))
        .toList();

    return HomeView(uploadedByMe: uploaded, assignedToMe: assigned);
  }

  // ───────────────────────── Realtime (SSE) ─────────────────────────

  Future<void> connectRealtime() async {
    if (_disposed || _connected) return;

    Future<void> start() async {
      if (_disposed || _connected) return;

      // Make sure we have a valid token; this will refresh+persist if expiring.
      final ok = await authRepo.hasValidToken();
      if (!ok) return;

      final token = await authRepo.getPersistedToken();
      if (token == null || token.isEmpty) return;

      _esSub = SSEClient
          .subscribeToSSE(
        method: SSERequestType.GET,
        url: '$baseUrl/api/home/stream',
        header: {
          HttpHeaders.authorizationHeader: 'Bearer $token',
          'Accept': 'text/event-stream',
          'Cache-Control': 'no-cache',
        },
      )
          .listen(
            (evt) {
          if (!_realtime.isClosed) {
            _realtime.add(null);
          }
        },
        onError: (e, st) {
          _scheduleRetry(start);
        },
        onDone: () {
          _scheduleRetry(start);
        },
        cancelOnError: true,
      );
    }

    await start();
  }

  void _scheduleRetry(Future<void> Function() start) {
    unawaited(_esSub?.cancel());
    _esSub = null;
    if (_disposed) return;
    if (_retryTimer != null) return;

    _retryTimer = Timer(const Duration(seconds: 5), () {
      _retryTimer = null;
      if (!_disposed && !_connected) {
        unawaited(start());
      }
    });
  }

  // ───────────────────────── Cleanup ─────────────────────────

  Future<void> dispose() async {
    _disposed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    await _esSub?.cancel();
    _esSub = null;
    await _realtime.close();
  }
}
