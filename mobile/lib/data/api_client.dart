import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);
  @override
  String toString() => message;
}
class ApiClient {
  static const baseUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8000/api');
  final http.Client client;
  final storage = const FlutterSecureStorage();
  String? token;
  bool offline = false;
  ApiClient({http.Client? client}) : client = client ?? http.Client();
  Future<void> init() async { token = await storage.read(key: 'access_token'); }
  Future<void> setToken(String? value) async {
    token = value;
    if (value == null) { await storage.delete(key: 'access_token'); }
    else { await storage.write(key: 'access_token', value: value); }
  }
  Future<dynamic> request(String path, {String method = 'GET', Map<String, dynamic>? body, bool cache = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'cache:$path';
    try {
      final req = http.Request(method, Uri.parse('$baseUrl/$path'));
      req.headers.addAll({'Accept': 'application/json', 'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'});
      if (body != null) req.body = jsonEncode(body);
      final response = await http.Response.fromStream(await client.send(req).timeout(const Duration(seconds: 25)));
      dynamic payload;
      try { payload = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body); }
      catch (_) { throw ApiException(response.statusCode, 'service_unavailable'); }
      if (response.statusCode >= 400) {
        if (response.statusCode == 401) await setToken(null);
        throw ApiException(response.statusCode, payload is Map ? payload['message'] ?? 'service_unavailable' : 'service_unavailable');
      }
      offline = false;
      if (cache && method == 'GET') await prefs.setString(cacheKey, jsonEncode({'data': payload, 'saved_at': DateTime.now().toIso8601String()}));
      return payload;
    } catch (error) {
      if (error is ApiException && error.status < 500) rethrow;
      if (cache && method == 'GET') {
        final saved = prefs.getString(cacheKey);
        if (saved != null) {
          offline = true;
          final entry = jsonDecode(saved);
          final payload = entry['data'];
          if (payload is Map<String, dynamic>) { payload['stale'] = true; payload['cached_at'] = entry['saved_at']; }
          return payload;
        }
      }
      if (error is ApiException) rethrow;
      throw ApiException(0, 'no_internet');
    }
  }
  Future<void> logout() async {
    try { await request('auth/logout', method: 'POST'); } finally {
      await setToken(null);
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys().where((k) => k.startsWith('cache:'))) { await prefs.remove(key); }
    }
  }
}
