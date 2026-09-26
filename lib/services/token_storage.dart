import 'package:shared_preferences/shared_preferences.dart';

/// Penyimpanan token JWT via SharedPreferences. Dipilih daripada
/// flutter_secure_storage: ini alat internal LAN dengan threat model rendah
/// (server tidak pernah terekspos ke internet), jadi setup Android Keystore
/// tidak diperlukan -- trade-off yang disengaja, bukan kelalaian.
class TokenStorage {
  TokenStorage._();
  static final TokenStorage instance = TokenStorage._();

  static const _tokenKey = 'auth_token';

  Future<void> save(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}
