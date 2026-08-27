import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();

  static String? token;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  static Future<dynamic> get(String path) async {
    return _request('GET', path);
  }

  static Future<dynamic> post(String path, {Object? body}) async {
    return _request('POST', path, body: body);
  }

  static Future<dynamic> _request(
    String method,
    String path, {
    Object? body,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    final headers = _headers;

    http.Response response;
    if (method == 'GET') {
      response = await http.get(uri, headers: headers);
    } else if (method == 'POST') {
      response = await http.post(
        uri,
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      );
    } else {
      throw UnsupportedError('Unsupported method: $method');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(utf8.decode(response.bodyBytes));
    }

    String message = 'Request failed';
    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final detail = data['detail'];
      if (detail is String) message = detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] != null) message = first['msg'].toString();
      }
    } catch (_) {
      // Keep the generic message.
    }

    throw ApiException(message, statusCode: response.statusCode);
  }
}
