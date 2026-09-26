import 'package:flutter/foundation.dart';

import '../data/models/pegawai.dart';
import '../data/repositories/pegawai_repository.dart';
import '../services/auth_service.dart';
import '../services/token_storage.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final PegawaiRepository _pegawaiRepository;

  Pegawai? _currentUser;
  Pegawai? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  AuthProvider({AuthService? authService, PegawaiRepository? pegawaiRepository})
      : _authService = authService ?? AuthService(),
        _pegawaiRepository = pegawaiRepository ?? PegawaiRepository();

  Future<void> login({required String username, required String password}) async {
    final user = await _authService.login(username: username, password: password);
    _currentUser = user;
    notifyListeners();
  }

  /// Dipanggil sekali saat app dibuka: mengecek token tersimpan lewat
  /// GET /api/auth/me, supaya login tidak perlu diulang tiap restart app.
  Future<void> tryAutoLogin() async {
    final user = await _authService.fetchCurrentUser();
    _currentUser = user;
    notifyListeners();
  }

  void logout() {
    _currentUser = null;
    TokenStorage.instance.clear();
    notifyListeners();
  }

  Future<void> refreshCurrentUser() async {
    if (_currentUser?.id == null) return;
    final refreshed = await _pegawaiRepository.findById(_currentUser!.id!);
    if (refreshed != null) {
      _currentUser = refreshed;
      notifyListeners();
    }
  }
}
