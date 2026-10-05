import 'package:shared_preferences/shared_preferences.dart';

/// Menyimpan alamat server GeoTani yang dipakai [ApiClient] untuk semua
/// request. Default-nya domain server VPS (lihat [_defaultBaseUrl]); bisa
/// ditimpa lewat ServerSettingsScreen.
class ApiConfig {
  ApiConfig._();
  static final ApiConfig instance = ApiConfig._();

  static const _prefsKey = 'server_base_url';

  /// Header yang ikut di SEMUA request ke server (API maupun Image.network).
  /// ngrok free menyisipkan halaman peringatan HTML di depan tiap request
  /// kecuali header ini ada -- tanpanya JSON/foto yang diterima app rusak.
  /// Tidak berpengaruh apa-apa kalau server diakses langsung via IP LAN.
  static const commonHeaders = {'ngrok-skip-browser-warning': 'true'};

  /// Default = domain server GeoTani di VPS (HTTPS via Apache, lihat
  /// server/deploy/README.md), jadi HP bisa dari jaringan mana saja (data seluler/WiFi
  /// lain). Tetap bisa diganti manual (IP LAN laptop atau ngrok) dari
  /// Pengaturan Server.
  static const _defaultBaseUrl = 'https://geotani.7sic4.online';

  String? _baseUrl = _defaultBaseUrl;

  bool get isConfigured => _baseUrl != null && _baseUrl!.isNotEmpty;

  /// Base URL tanpa trailing slash, mis. "http://192.168.1.2:3000".
  String get baseUrl {
    if (_baseUrl == null) {
      throw StateError('ApiConfig belum dikonfigurasi. Panggil load() dan set alamat server dahulu.');
    }
    return _baseUrl!;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null && saved.isNotEmpty) {
      try {
        _baseUrl = _normalize(saved);
      } on FormatException {
        // Nilai tersimpan entah bagaimana rusak -> kembali ke default,
        // bukan null, supaya app tidak nyangkut minta isi manual.
        _baseUrl = _defaultBaseUrl;
      }
    }
  }

  Future<void> setBaseUrl(String url) async {
    final normalized = _normalize(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, normalized);
    _baseUrl = normalized;
  }

  /// Melempar [FormatException] dengan pesan yang jelas (bukan error internal
  /// Dart seperti "No host specified in URI") kalau input kosong/tidak valid --
  /// tanpa ini, input kosong menghasilkan "http://" yang setelah trailing
  /// slash-nya ikut terpotong jadi "http:/" (base URL rusak, host hilang),
  /// baru gagal jauh belakangan saat request pertama dengan pesan membingungkan.
  String _normalize(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Alamat server tidak boleh kosong.');
    }
    var withScheme = trimmed;
    if (!withScheme.startsWith('http://') && !withScheme.startsWith('https://')) {
      withScheme = 'http://$withScheme';
    }
    // Buang trailing slash pada path, tapi jangan sampai memakan "//" dari
    // pemisah skema (mis. "http://" tanpa host sama sekali).
    while (withScheme.length > 'http://'.length && withScheme.endsWith('/')) {
      withScheme = withScheme.substring(0, withScheme.length - 1);
    }
    final parsed = Uri.tryParse(withScheme);
    if (parsed == null || parsed.host.isEmpty) {
      throw FormatException('Alamat server tidak valid: "$trimmed".');
    }
    return withScheme;
  }

  /// Mengubah path relatif dari server (mis. "/uploads/absensi/x.jpg") jadi
  /// URL lengkap untuk Image.network. Null/kosong -> null.
  String? resolveMediaUrl(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) return null;
    if (relativePath.startsWith('http://') || relativePath.startsWith('https://')) {
      return relativePath;
    }
    final path = relativePath.startsWith('/') ? relativePath : '/$relativePath';
    return '$baseUrl$path';
  }
}
