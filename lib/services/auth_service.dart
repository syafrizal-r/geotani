import '../data/models/pegawai.dart';
import 'api_client.dart';
import 'token_storage.dart';

class InvalidCredentialsException implements Exception {
  final String message;
  const InvalidCredentialsException([this.message = 'Username atau password salah.']);

  @override
  String toString() => message;
}

class AuthService {
  Future<Pegawai> login({required String username, required String password}) async {
    try {
      final result = await ApiClient.instance.post(
        '/api/auth/login',
        body: {'username': username.trim(), 'password': password},
      );
      final map = result as Map<String, dynamic>;
      await TokenStorage.instance.save(map['token'] as String);
      return Pegawai.fromMap(map['user'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 401) throw const InvalidCredentialsException();
      rethrow;
    }
  }

  /// Dipakai untuk auto-login: token tersimpan divalidasi ulang ke server.
  /// Null jika token tidak ada/sudah tidak valid.
  Future<Pegawai?> fetchCurrentUser() async {
    final token = await TokenStorage.instance.read();
    if (token == null) return null;
    try {
      final result = await ApiClient.instance.get('/api/auth/me');
      return Pegawai.fromMap((result as Map<String, dynamic>)['user'] as Map<String, dynamic>);
    } on ApiException {
      await TokenStorage.instance.clear();
      return null;
    }
  }
}
