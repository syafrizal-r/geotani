import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Layar kamera generik untuk mengambil foto selfie. Dipakai baik untuk
/// alur enrolment wajah maupun alur check-in/check-out.
///
/// Mengembalikan path file foto (String) lewat Navigator.pop, atau null
/// jika pengguna membatalkan.
class FaceCaptureScreen extends StatefulWidget {
  final String instruction;

  const FaceCaptureScreen({super.key, required this.instruction});

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen> {
  CameraController? _controller;
  Future<void>? _initFuture;
  String? _error;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _initFuture = _init();
  }

  Future<void> _init() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() => _error = 'Izin kamera ditolak. Aplikasi memerlukan akses kamera untuk absen.');
      return;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      setState(() => _error = 'Tidak ada kamera yang tersedia pada perangkat ini.');
      return;
    }

    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await controller.initialize();
    if (!mounted) return;
    setState(() => _controller = controller);
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _capturing) return;
    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      // Pada sebagian perangkat, penulisan file foto ke disk belum tentu
      // selesai persis saat takePicture() selesai — tunggu sampai file
      // benar-benar terisi agar tidak diproses dalam keadaan korup/kosong.
      final savedFile = File(file.path);
      for (var attempt = 0; attempt < 10; attempt++) {
        if (await savedFile.exists() && await savedFile.length() > 0) break;
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (!mounted) return;
      Navigator.of(context).pop(file.path);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal mengambil foto: $e';
        _capturing = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ambil Foto Wajah')),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (_error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            );
          }
          final controller = _controller;
          if (controller == null || !controller.value.isInitialized) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              Container(
                width: double.infinity,
                color: Colors.black87,
                padding: const EdgeInsets.all(12),
                child: Text(
                  widget.instruction,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(child: CameraPreview(controller)),
              Padding(
                padding: const EdgeInsets.all(24),
                child: FloatingActionButton.large(
                  onPressed: _capturing ? null : _capture,
                  child: _capturing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Icon(Icons.camera_alt),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
