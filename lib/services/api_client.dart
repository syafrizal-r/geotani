import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import 'token_storage.dart';

/// Dilempar untuk semua response non-2xx dari server GeoTani, supaya
/// pemanggil (mis. form screens) bisa membedakan error validasi/duplikat
/// dari error jaringan lain tanpa bergantung pada tipe exception sqflite lama.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

/// Wrapper tipis di atas package:http untuk semua komunikasi ke server
/// GeoTani lokal (LAN). Otomatis melampirkan token JWT tersimpan dan
/// menerjemahkan response non-2xx menjadi [ApiException].
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(ApiConfig.instance.baseUrl);
    return base.replace(path: '${base.path}$path', queryParameters: query);
  }

  Future<Map<String, String>> _headers({bool withJsonContentType = true}) async {
    final token = await TokenStorage.instance.read();
    return {
      ...ApiConfig.commonHeaders,
      if (withJsonContentType) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }
    var message = 'Terjadi kesalahan pada server (${response.statusCode}).';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] != null) {
        message = decoded['error'].toString();
      }
    } catch (_) {
      // respons bukan JSON, pakai pesan default di atas
    }
    throw ApiException(response.statusCode, message);
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final response = await http.get(_uri(path, query), headers: await _headers(withJsonContentType: false));
    return _decode(response);
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    final response = await http.post(
      _uri(path),
      headers: await _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> put(String path, {Map<String, dynamic>? body}) async {
    final response = await http.put(
      _uri(path),
      headers: await _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) async {
    final response = await http.patch(
      _uri(path),
      headers: await _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> delete(String path) async {
    final response = await http.delete(_uri(path), headers: await _headers(withJsonContentType: false));
    return _decode(response);
  }

  /// POST/PUT multipart untuk endpoint yang menerima upload foto (absensi,
  /// laporan). [file] null berarti tidak ada foto baru (server tetap
  /// mempertahankan foto lama jika ini request PUT).
  Future<dynamic> multipart(
    String method,
    String path, {
    required Map<String, String> fields,
    File? file,
    String fileField = 'foto',
  }) async {
    final request = http.MultipartRequest(method, _uri(path));
    final token = await TokenStorage.instance.read();
    request.headers.addAll(ApiConfig.commonHeaders);
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.fields.addAll(fields);
    if (file != null) {
      request.files.add(await http.MultipartFile.fromPath(fileField, file.path));
    }
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }
}
