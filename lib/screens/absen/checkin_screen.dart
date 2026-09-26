import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../data/models/absensi.dart';
import '../../data/models/lokasi.dart';
import '../../data/models/spt.dart';
import '../../providers/auth_provider.dart';
import '../../services/absensi_service.dart';
import '../../services/location_service.dart';
import '../camera/face_capture_screen.dart';

enum _Step { location, face, submitting, result }

/// Alur check-in/check-out sesuai activity diagram:
/// validasi GPS -> (jika di luar radius, ulangi) -> validasi wajah (liveness
/// + kecocokan, maksimal 3 percobaan) -> simpan hasil akhir.
class CheckinScreen extends StatefulWidget {
  final Spt spt;
  final Lokasi lokasi;
  final TipeAbsensi tipe;

  const CheckinScreen({
    super.key,
    required this.spt,
    required this.lokasi,
    required this.tipe,
  });

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  final _absensiService = AbsensiService();

  _Step _step = _Step.location;
  bool _loading = false;
  String? _error;

  LocationValidationResult? _locationResult;
  int _faceAttempt = 0;
  Absensi? _finalResult;
  FaceCheckResult? _lastFaceResult;

  @override
  void initState() {
    super.initState();
    _checkLocation();
  }

  Future<void> _checkLocation() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _absensiService.validateLocation(widget.lokasi);
      setState(() {
        _locationResult = result;
        _step = result.dalamRadius ? _Step.face : _Step.location;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _captureAndCheckFace() async {
    final user = context.read<AuthProvider>().currentUser!;

    final imagePath = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => FaceCaptureScreen(
          instruction: 'Percobaan ${_faceAttempt + 1} dari ${AppConstants.maxFaceRetryAttempts}. '
              'Posisikan wajah menghadap lurus ke kamera.',
        ),
      ),
    );
    if (imagePath == null || !mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final faceResult = await _absensiService.checkFace(imagePath: imagePath, pegawai: user);
      _faceAttempt++;
      _lastFaceResult = faceResult;

      if (faceResult.isAccepted) {
        await _submit(imagePath: imagePath, faceResult: faceResult);
        return;
      }

      if (_faceAttempt >= AppConstants.maxFaceRetryAttempts) {
        await _submit(imagePath: imagePath, faceResult: faceResult);
        return;
      }

      setState(() => _error = faceResult.rejectReason);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit({required String imagePath, required FaceCheckResult faceResult}) async {
    final user = context.read<AuthProvider>().currentUser!;
    setState(() => _step = _Step.submitting);
    final result = await _absensiService.submit(
      spt: widget.spt,
      pegawai: user,
      tipe: widget.tipe,
      location: _locationResult!,
      faceResult: faceResult,
      fotoPath: imagePath,
    );
    setState(() {
      _finalResult = result;
      _step = _Step.result;
    });
  }

  @override
  void dispose() {
    _absensiService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.tipe.label)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: switch (_step) {
          _Step.location => _buildLocationStep(),
          _Step.face => _buildFaceStep(),
          _Step.submitting => const Center(child: CircularProgressIndicator()),
          _Step.result => _buildResultStep(),
        },
      ),
    );
  }

  Widget _buildLocationStep() {
    final result = _locationResult;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_loading) const CircularProgressIndicator(),
          if (!_loading && result != null && result.isMocked) ...[
            const Icon(Icons.gps_off, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Lokasi palsu terdeteksi.\n'
              'Matikan aplikasi Fake GPS / mock location di ponsel Anda, '
              'lalu cek ulang lokasi.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _checkLocation,
              icon: const Icon(Icons.refresh),
              label: const Text('Cek Ulang Lokasi'),
            ),
          ],
          if (!_loading && result != null && !result.isMocked && !result.dalamRadius) ...[
            const Icon(Icons.location_off, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Anda berada di luar radius lokasi tugas.\n'
              'Jarak saat ini: ${result.jarakMeter.toStringAsFixed(0)} m '
              '(radius diizinkan: ${widget.lokasi.radiusMeter.toInt()} m).',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _checkLocation,
              icon: const Icon(Icons.refresh),
              label: const Text('Cek Ulang Lokasi'),
            ),
          ],
          if (!_loading && _error != null && result == null) ...[
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _checkLocation,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFaceStep() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 48, color: Colors.green),
          const SizedBox(height: 8),
          Text(
            'Lokasi tervalidasi (jarak ${_locationResult!.jarakMeter.toStringAsFixed(0)} m). '
            'Lanjutkan dengan validasi wajah.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            const SizedBox(height: 16),
          ],
          if (_loading)
            const CircularProgressIndicator()
          else
            FilledButton.icon(
              onPressed: _captureAndCheckFace,
              icon: const Icon(Icons.camera_alt),
              label: Text(_faceAttempt == 0 ? 'Ambil Foto Wajah' : 'Coba Lagi'),
            ),
        ],
      ),
    );
  }

  Widget _buildResultStep() {
    final result = _finalResult!;
    final ok = result.status == StatusAbsensi.tervalidasi;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.cancel,
            size: 72,
            color: ok ? Colors.green : Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            ok ? '${widget.tipe.label} Berhasil' : '${widget.tipe.label} Ditolak',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(result.status.label, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            'Jarak: ${result.jarakMeter.toStringAsFixed(0)} m · '
            'Kemiripan wajah: ${(result.faceSimilarity * 100).toStringAsFixed(0)}%',
            textAlign: TextAlign.center,
          ),
          if (!ok && _lastFaceResult?.rejectReason != null) ...[
            const SizedBox(height: 8),
            Text(_lastFaceResult!.rejectReason!, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Kembali'),
          ),
        ],
      ),
    );
  }
}
