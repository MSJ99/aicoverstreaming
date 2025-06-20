import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  late final http.Client client;

  ApiClient._internal() {
    client = http.Client();
  }

  Future<http.Response> get(Uri url, {Map<String, String>? headers}) {
    return client.get(url, headers: headers);
  }

  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    return client.post(url, headers: headers, body: body, encoding: encoding);
  }

  Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    return client.delete(url, headers: headers, body: body, encoding: encoding);
  }

  void dispose() {
    client.close();
  }
}
