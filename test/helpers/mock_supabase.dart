import 'dart:convert';

import 'package:envisionfit/supabase/supabase_config.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles one call to a Supabase Edge Function. Receives the decoded JSON
/// body the app sent and returns the HTTP response the function should give.
typedef FunctionHandler = http.Response Function(Map<String, dynamic> body);

/// A [SupabaseClient] wired to an in-memory HTTP transport.
///
/// Every request the app makes through `SupabaseConfig.client` lands in
/// [requests]; Edge Function calls are routed to handlers registered with
/// [onFunction]. Anything not mocked gets a 404, so the test fails loudly
/// instead of reaching the real backend.
class MockSupabase {
  final List<http.Request> requests = [];
  final Map<String, FunctionHandler> _functions = {};

  /// Creates the mock and installs it as `SupabaseConfig.client`.
  MockSupabase() {
    SupabaseConfig.clientOverride = SupabaseClient(
      'https://test.supabase.co',
      'test-anon-key',
      httpClient: MockClient(_handle),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  }

  /// Removes the override so later tests start clean.
  void dispose() {
    SupabaseConfig.clientOverride?.dispose();
    SupabaseConfig.clientOverride = null;
  }

  void onFunction(String name, FunctionHandler handler) {
    _functions[name] = handler;
  }

  /// Decoded JSON bodies sent to the Edge Function [name], in call order.
  List<Map<String, dynamic>> callsTo(String name) => requests
      .where((r) => _functionName(r) == name)
      .map((r) => Map<String, dynamic>.from(jsonDecode(r.body) as Map))
      .toList();

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request);
    final name = _functionName(request);
    final handler = name == null ? null : _functions[name];
    if (handler == null) {
      return http.Response('Not mocked: ${request.method} ${request.url}', 404);
    }
    final body =
        request.body.isEmpty ? <String, dynamic>{} : Map<String, dynamic>.from(jsonDecode(request.body) as Map);
    return handler(body);
  }

  static String? _functionName(http.Request request) {
    final seg = request.url.pathSegments;
    if (seg.length >= 3 && seg[0] == 'functions' && seg[1] == 'v1') {
      return seg[2];
    }
    return null;
  }
}

/// A JSON response, as an Edge Function returning an object would send it.
http.Response jsonResponse(Object body, {int status = 200}) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );
