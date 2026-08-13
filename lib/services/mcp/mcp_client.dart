// lib/services/mcp/mcp_client.dart
//
// JSON-RPC 2.0 transport for MCP servers over plain HTTPS.
//
// The server may answer either as application/json or as text/event-stream
// for the SAME request, so both are handled. This is not a streaming client:
// the full body is read, then data: lines are joined and parsed as one JSON
// document — which is what the Node prototype does and what the endpoint
// actually returns today.
//
// Deliberately partner-agnostic. Nothing here knows about Swiggy; the
// endpoint, the bearer token and the tool names are all supplied by the
// caller, so the same transport serves any MCP partner.

import 'dart:convert';
import 'package:http/http.dart' as http;

/// Thrown when the server returns a JSON-RPC error, an isError result, or
/// an unparseable body. Carries the raw payload so callers can log it.
class McpException implements Exception {
  final String toolName;
  final String message;
  final Object? payload;

  McpException(this.toolName, this.message, [this.payload]);

  @override
  String toString() => 'McpException($toolName): $message';
}

class McpClient {
  final Uri endpoint;

  /// Supplied per call rather than stored, so a refreshed token is picked up
  /// without rebuilding the client. Tokens belong in Android Keystore, never
  /// in this object and never in the APK.
  final Future<String> Function() accessToken;

  final http.Client _http;
  final Duration timeout;

  int _rpcId = 0;

  McpClient({
    required this.endpoint,
    required this.accessToken,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 30),
  }) : _http = httpClient ?? http.Client();

  /// Calls an MCP tool and returns the `result` object.
  Future<Map<String, dynamic>> callTool(
    String name,
    Map<String, dynamic> args,
  ) async {
    final token = await accessToken();

    final res = await _http
        .post(
          endpoint,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            // Both must be offered — the server picks the response format.
            'Accept': 'application/json, text/event-stream',
          },
          body: jsonEncode({
            'jsonrpc': '2.0',
            'id': ++_rpcId,
            'method': 'tools/call',
            'params': {'name': name, 'arguments': args},
          }),
        )
        .timeout(timeout);

    final contentType = res.headers['content-type'] ?? '';

    // utf8.decode over res.body: http defaults to latin1 when the server
    // omits a charset, which mangles rupee signs and Devanagari.
    final rawBody = utf8.decode(res.bodyBytes);

    Map<String, dynamic> body;
    if (contentType.contains('text/event-stream')) {
      body = _parseEventStream(rawBody, name);
    } else {
      try {
        body = jsonDecode(rawBody) as Map<String, dynamic>;
      } catch (_) {
        throw McpException(name, 'response was not valid JSON', rawBody);
      }
    }

    if (body['error'] != null) {
      throw McpException(name, 'server returned an error', body['error']);
    }

    final result = body['result'];
    if (result is! Map<String, dynamic>) {
      throw McpException(name, 'result missing or not an object', body);
    }

    // MCP signals tool-level failure inside a 200 response.
    if (result['isError'] == true) {
      throw McpException(name, 'tool reported an error', result);
    }

    return result;
  }

  /// Joins `data:` lines into one JSON document, mirroring the Node client.
  Map<String, dynamic> _parseEventStream(String rawBody, String toolName) {
    final dataLines = rawBody
        .split(RegExp(r'\r?\n'))
        .where((line) => line.startsWith('data:'))
        .map((line) => line.substring(5).trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (dataLines.isEmpty) {
      throw McpException(toolName, 'empty event-stream response', rawBody);
    }

    try {
      return jsonDecode(dataLines.join('\n')) as Map<String, dynamic>;
    } catch (_) {
      throw McpException(
          toolName, 'event-stream payload was not valid JSON', dataLines.join('\n'));
    }
  }

  void dispose() => _http.close();
}