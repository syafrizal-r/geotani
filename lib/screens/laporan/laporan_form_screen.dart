import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../data/models/laporan.dart';
import '../../data/models/spt.dart';
import '../../data/repositories/laporan_repository.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/network_or_placeholder_image.dart';

/// Form pengisian laporan hasil kunjungan (foto lahan/tanaman + catatan)
/// sesuai kebutuhan fungsional #9: PPL mengunggah laporan hasil kunjungan.
class LaporanFormScreen extends StatefulWidget {
  final Spt spt;
  final Laporan? existing;

  const LaporanFormScreen({super.key, required this.spt, this.existing});

  @override
  State<LaporanFormScreen> createState() => _LaporanFormScreenState();
}

class _LaporanFormScreenState extends State<LaporanFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _catatanController = TextEditingController();
  final _laporanRepository = LaporanRepository();
  final _picker = ImagePicker();

  // _fotoPath: URL server dari foto yang sudah tersimpan (saat mengedit).
  // _newPhotoFile: file lokal baru yang baru dipilih user sesi ini, belum
  // diunggah. Keduanya dipisah karena _submit() perlu tahu apakah harus
  // mengunggah foto baru atau membiarkan foto lama di server tidak berubah.
  String? _fotoPath;
  File? _newPhotoFile;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _catatanController.text = widget.existing!.catatan;
      _fotoPath = widget.existing!.fotoPath;
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final file = await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (file == null) return;
    setState(() => _newPhotoFile = File(file.path));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = context.read<AuthProvider>().currentUser!;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final laporan = Laporan(
        id: widget.existing?.id,
        sptId: widget.spt.id!,
        pegawaiId: user.id!,
        catatan: _catatanController.text.trim(),
        fotoPath: _fotoPath,
        waktuDibuat: DateTime.now(),
      );
      if (widget.existing == null) {
        await _laporanRepository.insert(laporan, newFotoFile: _newPhotoFile);
      } else {
        await _laporanRepository.update(laporan, newFotoFile: _newPhotoFile);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _catatanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan Hasil Kunjungan')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(widget.spt.agenda, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            if (_newPhotoFile != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(_newPhotoFile!, height: 220, fit: BoxFit.cover),
              )
            else if (_fotoPath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: NetworkOrPlaceholderImage(path: _fotoPath, height: 220),
              )
            else
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text('Belum ada foto lahan/tanaman', style: TextStyle(color: Colors.black54)),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickPhoto(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Kamera'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickPhoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galeri'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _catatanController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Catatan hasil kunjungan',
                hintText: 'Kondisi lahan/tanaman, hama/penyakit, materi penyuluhan, dsb.',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Catatan wajib diisi' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(widget.existing == null ? 'Simpan Laporan' : 'Perbarui Laporan'),
            ),
          ],
        ),
      ),
    );
  }
}
