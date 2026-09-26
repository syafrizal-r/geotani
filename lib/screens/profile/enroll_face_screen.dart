import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/pegawai_repository.dart';
import '../../providers/auth_provider.dart';
import '../../services/face_liveness_service.dart';
import '../../services/face_recognition_service.dart';
import '../camera/face_capture_screen.dart';

/// Alur enrolment wajah: PPL mengambil selfie sekali untuk dijadikan
/// data wajah referensi yang akan dibandingkan setiap kali check-in/out.
class EnrollFaceScreen extends StatefulWidget {
  const EnrollFaceScreen({super.key});

  @override
  State<EnrollFaceScreen> createState() => _EnrollFaceScreenState();
}

class _EnrollFaceScreenState extends State<EnrollFaceScreen> {
  final _livenessService = FaceLivenessService();
  final _recognitionService = FaceRecognitionService();
  final _pegawaiRepository = PegawaiRepository();

  bool _processing = false;
  String? _message;
  bool _success = false;

  Future<void> _startEnrollment() async {
    final imagePath = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const FaceCaptureScreen(
          instruction: 'Posisikan wajah Anda di tengah kamera dengan pencahayaan cukup, '
              'lalu tekan tombol untuk mengambil foto referensi.',
        ),
      ),
    );
    if (imagePath == null || !mounted) return;

    final authProvider = context.read<AuthProvider>();

    setState(() {
      _processing = true;
      _message = null;
    });

    try {
      final liveness = await _livenessService.analyze(imagePath);
      if (!liveness.isLive) {
        setState(() {
          _message = liveness.rejectReason ?? 'Foto tidak valid, silakan ulangi.';
          _success = false;
        });
        return;
      }

      final embedding = await _recognitionService.extractEmbedding(
        imagePath: imagePath,
        faceBoundingBox: liveness.face.boundingBox,
      );

      final user = authProvider.currentUser!;
      await _pegawaiRepository.saveFaceEmbedding(user.id!, embedding);
      await authProvider.refreshCurrentUser();

      setState(() {
        _message = 'Wajah referensi berhasil didaftarkan.';
        _success = true;
      });
    } catch (e) {
      setState(() {
        _message = e.toString();
        _success = false;
      });
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  void dispose() {
    _livenessService.dispose();
    _recognitionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enrolment Wajah Referensi')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.face_retouching_natural, size: 72, color: Colors.green),
              const SizedBox(height: 16),
              const Text(
                'Data wajah ini akan menjadi acuan pencocokan setiap kali Anda '
                'melakukan check-in/check-out tugas lapangan.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _message!,
                    style: TextStyle(color: _success ? Colors.green[800] : Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              FilledButton.icon(
                onPressed: _processing ? null : _startEnrollment,
                icon: _processing
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.camera_alt),
                label: Text(_success ? 'Ambil Ulang' : 'Ambil Foto Wajah'),
              ),
              if (_success) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Selesai'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
