import '../core/constants.dart';
import '../data/models/absensi.dart';
import '../data/models/lokasi.dart';
import '../data/models/pegawai.dart';
import '../data/models/spt.dart';
import '../data/repositories/absensi_repository.dart';
import 'face_liveness_service.dart';
import 'face_recognition_service.dart';
import 'location_service.dart';

class FaceCheckResult {
  final bool isLive;
  final bool matched;
  final double similarity;
  final String? rejectReason;

  const FaceCheckResult({
    required this.isLive,
    required this.matched,
    required this.similarity,
    this.rejectReason,
  });

  bool get isAccepted => isLive && matched;
}

/// Mengorkestrasi alur validasi absen (check-in/check-out) sesuai activity
/// diagram: validasi lokasi GPS -> validasi liveness -> validasi kecocokan
/// wajah -> simpan hasil akhir.
class AbsensiService {
  final LocationService _locationService;
  final FaceLivenessService _livenessService;
  final FaceRecognitionService _recognitionService;
  final AbsensiRepository _absensiRepository;

  AbsensiService({
    LocationService? locationService,
    FaceLivenessService? livenessService,
    FaceRecognitionService? recognitionService,
    AbsensiRepository? absensiRepository,
  })  : _locationService = locationService ?? LocationService(),
        _livenessService = livenessService ?? FaceLivenessService(),
        _recognitionService = recognitionService ?? FaceRecognitionService(),
        _absensiRepository = absensiRepository ?? AbsensiRepository();

  Future<LocationValidationResult> validateLocation(Lokasi lokasi) {
    return _locationService.validateAgainst(
      targetLatitude: lokasi.latitude,
      targetLongitude: lokasi.longitude,
      radiusMeter: lokasi.radiusMeter,
    );
  }

  /// Menjalankan liveness check lalu mencocokkan wajah pada [imagePath]
  /// dengan embedding referensi milik [pegawai].
  Future<FaceCheckResult> checkFace({
    required String imagePath,
    required Pegawai pegawai,
  }) async {
    final liveness = await _livenessService.analyze(imagePath);
    if (!liveness.isLive) {
      return FaceCheckResult(
        isLive: false,
        matched: false,
        similarity: 0,
        rejectReason: liveness.rejectReason,
      );
    }

    if (!pegawai.isEnrolled) {
      return const FaceCheckResult(
        isLive: true,
        matched: false,
        similarity: 0,
        rejectReason: 'Wajah referensi belum terdaftar. Lakukan enrolment wajah di menu Profil.',
      );
    }

    final embedding = await _recognitionService.extractEmbedding(
      imagePath: imagePath,
      faceBoundingBox: liveness.face.boundingBox,
    );

    final similarity = _recognitionService.cosineSimilarity(
      embedding,
      pegawai.embeddingVector,
    );

    final matched = similarity >= AppConstants.faceMatchThreshold;

    return FaceCheckResult(
      isLive: true,
      matched: matched,
      similarity: similarity,
      rejectReason: matched ? null : 'Wajah tidak cocok dengan data referensi.',
    );
  }

  Future<Absensi> submit({
    required Spt spt,
    required Pegawai pegawai,
    required TipeAbsensi tipe,
    required LocationValidationResult location,
    required FaceCheckResult faceResult,
    String? fotoPath,
  }) async {
    final StatusAbsensi status;
    if (!location.dalamRadius) {
      status = StatusAbsensi.ditolakLokasi;
    } else if (!faceResult.isAccepted) {
      status = StatusAbsensi.ditolakWajah;
    } else {
      status = StatusAbsensi.tervalidasi;
    }

    final absensi = Absensi(
      sptId: spt.id!,
      pegawaiId: pegawai.id!,
      tipe: tipe,
      waktu: DateTime.now(),
      latitude: location.position.latitude,
      longitude: location.position.longitude,
      jarakMeter: location.jarakMeter,
      faceSimilarity: faceResult.similarity,
      status: status,
      fotoPath: fotoPath,
    );

    // insert() mengembalikan objek penuh (bukan cuma id) karena foto_path
    // yang dikembalikan server adalah URL hasil upload, beda dari fotoPath
    // lokal yang dikirim di atas.
    return _absensiRepository.insert(absensi, isMocked: location.isMocked);
  }

  void dispose() {
    _livenessService.dispose();
    _recognitionService.dispose();
  }
}
