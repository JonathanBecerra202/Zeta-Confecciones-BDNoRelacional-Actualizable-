import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const _tokenKey = 'zeta_access_token';
  final String baseUrl = Env.apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
  final http.Client _http = http.Client();

  String? _token;
  final _authController = StreamController<String?>.broadcast();

  String? get token => _token;
  Stream<String?> get onTokenChange => _authController.stream;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
  }

  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null || token.isEmpty) {
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, token);
    }
    _authController.add(_token);
  }

  String resolveUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final normalized = path.startsWith('/') ? path : '/$path';
    return '$baseUrl$normalized';
  }

  Map<String, String> _headers({bool jsonBody = false}) => {
        if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
        if (jsonBody) 'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$baseUrl$normalized');
    if (query == null || query.isEmpty) return uri;

    final params = <String, dynamic>{};
    query.forEach((k, v) {
      if (v == null) return;
      if (v is List) {
        params[k] = v.map((e) => e.toString()).toList();
      } else {
        params[k] = v.toString();
      }
    });
    return uri.replace(queryParameters: params);
  }

  dynamic _handleResponse(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.bodyBytes.isEmpty) return null;
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    String message = 'Error del servidor (${res.statusCode}).';
    if (res.bodyBytes.isNotEmpty) {
      try {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        if (decoded is Map) {
          if (decoded['detail'] is String) {
            message = decoded['detail'] as String;
          } else if (decoded['detail'] is List && (decoded['detail'] as List).isNotEmpty) {
            final first = (decoded['detail'] as List).first;
            if (first is Map && first['msg'] != null) {
              message = first['msg'].toString();
            }
          } else if (decoded['error'] != null) {
            message = decoded['error'].toString();
          }
        }
      } catch (_) {}
    }
    throw ApiException(res.statusCode, message);
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    final res = await _http.get(_uri(path, query), headers: _headers());
    return _handleResponse(res);
  }

  Future<dynamic> post(String path, {Object? body}) async {
    final res = await _http.post(
      _uri(path),
      headers: _headers(jsonBody: body != null),
      body: body == null ? null : jsonEncode(body),
    );
    return _handleResponse(res);
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    final res = await _http.patch(
      _uri(path),
      headers: _headers(jsonBody: body != null),
      body: body == null ? null : jsonEncode(body),
    );
    return _handleResponse(res);
  }

  Future<dynamic> delete(String path) async {
    final res = await _http.delete(_uri(path), headers: _headers());
    return _handleResponse(res);
  }

  Future<dynamic> uploadFile(
    String path, {
    required Uint8List bytes,
    required String contentType,
    required String filename,
  }) async {
    final req = http.MultipartRequest('POST', _uri(path));
    if (_token != null && _token!.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $_token';
    }
    req.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: MediaType.parse(contentType),
      ),
    );
    final streamed = await _http.send(req);
    final res = await http.Response.fromStream(streamed);
    return _handleResponse(res);
  }
}
