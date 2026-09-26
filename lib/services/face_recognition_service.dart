import 'dart:io';
import 'dart:math';

import 'dart:ui' show Rect;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../core/constants.dart';

class FaceModelNotLoadedException implements Exception {
  final String message;
  const FaceModelNotLoadedException([
    this.message =
        'Model face recognition (assets/models/mobilefacenet.tflite) belum tersedia. '
        'Lihat assets/models/README.md untuk cara mendapatkannya.',
  ]);

  @override
  String toString() => message;
}

/// Menghasilkan embedding wajah (vector angka) memakai model TFLite on-device
/// (mis. MobileFaceNet), lalu membandingkannya dengan cosine similarity.
///
/// Model TIDAK disertakan di repo (file biner) — service ini gagal secara
/// terkontrol (bukan crash) jika model belum diletakkan di assets/models/.
class FaceRecognitionService {
  Interpreter? _interpreter;
  bool _loadFailed = false;

  Future<void> _ensureModelLoaded() async {
    if (_interpreter != null || _loadFailed) return;
    try {
      _interpreter = await Interpreter.fromAsset(AppConstants.faceModelAssetPath);
    } catch (_) {
      _loadFailed = true;
    }
    if (_interpreter == null) {
      throw const FaceModelNotLoadedException();
    }
  }

  /// Menghasilkan embedding dari file foto, dipotong sesuai [faceBoundingBox]
  /// (koordinat dari hasil deteksi wajah ML Kit).
  Future<List<double>> extractEmbedding({
    required String imagePath,
    required Rect faceBoundingBox,
  }) async {
    await _ensureModelLoaded();

    final bytes = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FaceModelNotLoadedException(
        'Gagal membaca file foto untuk diproses.',
      );
    }

    final x = faceBoundingBox.left.clamp(0, decoded.width - 1).toInt();
    final y = faceBoundingBox.top.clamp(0, decoded.height - 1).toInt();
    final w = faceBoundingBox.width.clamp(1, decoded.width - x).toInt();
    final h = faceBoundingBox.height.clamp(1, decoded.height - y).toInt();

    final cropped = img.copyCrop(decoded, x: x, y: y, width: w, height: h);
    final resized = img.copyResize(
      cropped,
      width: AppConstants.faceInputSize,
      height: AppConstants.faceInputSize,
    );

    final input = _imageToInputTensor(resized);
    final output = [List.filled(AppConstants.faceEmbeddingSize, 0.0)];

    try {
      _interpreter!.run(input, output);
    } catch (e, st) {
      debugPrint('FaceRecognitionService: gagal menjalankan model wajah: $e\n$st');
      throw const FaceModelNotLoadedException(
        'Gagal memproses model pengenalan wajah. Coba ambil ulang foto.',
      );
    }

    return List<double>.from(output.first);
  }

  List<List<List<List<double>>>> _imageToInputTensor(img.Image image) {
    final size = AppConstants.faceInputSize;
    return [
      List.generate(size, (y) {
        return List.generate(size, (x) {
          final pixel = image.getPixel(x, y);
          return [
            (pixel.r - 127.5) / 128.0,
            (pixel.g - 127.5) / 128.0,
            (pixel.b - 127.5) / 128.0,
          ];
        });
      }),
    ];
  }

  double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0;
    double dot = 0, normA = 0, normB = 0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0;
    return dot / (sqrt(normA) * sqrt(normB));
  }

  void dispose() {
    _interpreter?.close();
  }
}
