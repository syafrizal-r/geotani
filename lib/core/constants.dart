/// Konstanta konfigurasi aplikasi GeoTani.
class AppConstants {
  AppConstants._();

  /// Radius default (meter) jika lokasi belum diset radius khususnya.
  static const double defaultRadiusMeter = 100;

  /// Ambang batas kemiripan wajah (cosine similarity) agar dianggap cocok.
  /// Nilai 0..1, semakin tinggi semakin ketat.
  static const double faceMatchThreshold = 0.75;

  /// Ukuran input gambar untuk model face recognition (mis. MobileFaceNet: 112x112).
  static const int faceInputSize = 112;

  /// Jumlah dimensi embedding output model (sesuaikan dengan model yang dipakai).
  static const int faceEmbeddingSize = 192;

  static const String faceModelAssetPath = 'assets/models/mobilefacenet.tflite';

  /// Ambang batas probabilitas mata terbuka untuk liveness check sederhana.
  static const double eyeOpenProbabilityThreshold = 0.4;

  static const int maxFaceRetryAttempts = 3;
}
