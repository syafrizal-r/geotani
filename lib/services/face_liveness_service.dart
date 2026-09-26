import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../core/constants.dart';

class LivenessResult {
  final Face face;
  final bool isLive;
  final String? rejectReason;

  const LivenessResult({
    required this.face,
    required this.isLive,
    this.rejectReason,
  });
}

class NoFaceDetectedException implements Exception {
  final String message;
  const NoFaceDetectedException([
    this.message = 'Wajah tidak terdeteksi. Pastikan wajah terlihat jelas dan pencahayaan cukup.',
  ]);

  @override
  String toString() => message;
}

/// Deteksi wajah + heuristik liveness sederhana (mata terbuka, sudut kepala wajar)
/// memakai Google ML Kit. Ini BUKAN anti-spoofing tingkat lanjut, hanya memastikan
/// foto yang diambil adalah wajah manusia dengan pose kooperatif, bukan foto/dokumen datar.
class FaceLivenessService {
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableClassification: true,
      enableTracking: false,
      minFaceSize: 0.25,
    ),
  );

  Future<LivenessResult> analyze(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final List<Face> faces;
    try {
      faces = await _detector.processImage(inputImage);
    } catch (e, st) {
      debugPrint('FaceLivenessService: gagal memproses gambar wajah: $e\n$st');
      throw const NoFaceDetectedException(
        'Gagal memproses foto wajah. Pastikan pencahayaan cukup, lalu coba ambil ulang foto.',
      );
    }

    if (faces.isEmpty) {
      throw const NoFaceDetectedException();
    }
    if (faces.length > 1) {
      return LivenessResult(
        face: faces.first,
        isLive: false,
        rejectReason: 'Terdeteksi lebih dari satu wajah pada kamera.',
      );
    }

    final face = faces.first;

    final leftEyeOpen = face.leftEyeOpenProbability;
    final rightEyeOpen = face.rightEyeOpenProbability;
    if (leftEyeOpen != null && leftEyeOpen < AppConstants.eyeOpenProbabilityThreshold ||
        rightEyeOpen != null && rightEyeOpen < AppConstants.eyeOpenProbabilityThreshold) {
      return LivenessResult(
        face: face,
        isLive: false,
        rejectReason: 'Mata terdeteksi tertutup, silakan ulangi dengan mata terbuka.',
      );
    }

    final headEulerY = face.headEulerAngleY ?? 0;
    final headEulerZ = face.headEulerAngleZ ?? 0;
    if (headEulerY.abs() > 25 || headEulerZ.abs() > 25) {
      return LivenessResult(
        face: face,
        isLive: false,
        rejectReason: 'Posisikan wajah menghadap lurus ke kamera.',
      );
    }

    return LivenessResult(face: face, isLive: true);
  }

  void dispose() {
    _detector.close();
  }
}
