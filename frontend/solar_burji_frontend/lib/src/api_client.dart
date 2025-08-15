import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class ApiClient {
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'X-API-KEY': AppConfig.apiKey,
    'Cache-Control': 'no-cache, no-store, must-revalidate',
    'Pragma': 'no-cache',
    'Expires': '0',
  };

  Uri _uri(String path, [Map<String, String>? query]) {
    // Add timestamp to prevent caching
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final cacheBustQuery = {...?query, '_t': timestamp.toString()};

    return Uri.parse(
      '${AppConfig.apiBaseUrl}$path',
    ).replace(queryParameters: cacheBustQuery);
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) async {
    // Create a new client for each request to prevent caching
    final client = http.Client();
    try {
      final response = await client.get(_uri(path, query), headers: _headers);
      return _decode(response);
    } finally {
      client.close();
    }
  }

  Uri buildUri(String path, {Map<String, String>? query}) => _uri(path, query);

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    // Create a new client for each request to prevent caching
    final client = http.Client();
    try {
      final response = await client.post(
        _uri(path),
        headers: _headers,
        body: jsonEncode(body),
      );
      return _decode(response);
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body,
  ) async {
    // Use POST with action parameter for production server compatibility
    final client = http.Client();
    try {
      final response = await client.post(
        _uri(path, {'action': 'update'}),
        headers: _headers,
        body: jsonEncode(body),
      );
      return _decode(response);
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, String>? query,
  }) async {
    // Use POST with action parameter for production server compatibility
    final client = http.Client();
    try {
      final response = await client.post(
        _uri(path, {...?query, 'action': 'delete'}),
        headers: _headers,
        body: jsonEncode({}),
      );
      return _decode(response);
    } finally {
      client.close();
    }
  }

  Map<String, dynamic> _decode(http.Response r) {
    try {
      final body = r.body.isEmpty ? '{}' : r.body;
      final data = jsonDecode(body) as Map<String, dynamic>;
      if (r.statusCode >= 400) {
        throw ApiException(
          r.statusCode,
          data['error']?.toString() ?? 'HTTP ${r.statusCode}',
        );
      }
      return data;
    } catch (_) {
      // Non-JSON response (often "file not found" or HTML). Surface raw body.
      final snippet = r.body.trim();
      final preview = snippet.length > 120
          ? '${snippet.substring(0, 120)}…'
          : snippet;
      throw ApiException(
        r.statusCode,
        preview.isEmpty ? 'Invalid response from server' : preview,
      );
    }
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => 'ApiException($statusCode): $message';
}
