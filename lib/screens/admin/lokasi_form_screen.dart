import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../data/models/lokasi.dart';
import '../../data/repositories/lokasi_repository.dart';

/// Form tambah/ubah lokasi (kelompok tani/lahan) untuk modul CRUD Admin Kepegawaian.
class LokasiFormScreen extends StatefulWidget {
  final Lokasi? existing;

  const LokasiFormScreen({super.key, this.existing});

  @override
  State<LokasiFormScreen> createState() => _LokasiFormScreenState();
}

class _LokasiFormScreenState extends State<LokasiFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _lokasiRepository = LokasiRepository();

  final _namaController = TextEditingController();
  final _alamatController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _radiusController = TextEditingController();

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _namaController.text = existing.nama;
      _alamatController.text = existing.alamat;
      _latitudeController.text = existing.latitude.toString();
      _longitudeController.text = existing.longitude.toString();
      _radiusController.text = existing.radiusMeter.toString();
    } else {
      _radiusController.text = AppConstants.defaultRadiusMeter.toString();
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _alamatController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  String? _validateDouble(String? v, {double? min, double? max}) {
    if (v == null || v.trim().isEmpty) return 'Wajib diisi';
    final parsed = double.tryParse(v.trim());
    if (parsed == null) return 'Harus berupa angka';
    if (min != null && parsed < min) return 'Minimal $min';
    if (max != null && parsed > max) return 'Maksimal $max';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final lokasi = Lokasi(
        id: widget.existing?.id,
        nama: _namaController.text.trim(),
        alamat: _alamatController.text.trim(),
        latitude: double.parse(_latitudeController.text.trim()),
        longitude: double.parse(_longitudeController.text.trim()),
        radiusMeter: double.parse(_radiusController.text.trim()),
      );

      if (_isEdit) {
        await _lokasiRepository.update(lokasi);
      } else {
        await _lokasiRepository.insert(lokasi);
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Ubah Lokasi' : 'Tambah Lokasi')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _namaController,
              decoration: const InputDecoration(
                labelText: 'Nama Lokasi',
                hintText: 'mis. Kelompok Tani Sido Makmur',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _alamatController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Alamat', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Alamat wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latitudeController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: const InputDecoration(labelText: 'Latitude', border: OutlineInputBorder()),
                    validator: (v) => _validateDouble(v, min: -90, max: 90),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _longitudeController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: const InputDecoration(labelText: 'Longitude', border: OutlineInputBorder()),
                    validator: (v) => _validateDouble(v, min: -180, max: 180),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _radiusController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Radius Geofence (meter)',
                border: OutlineInputBorder(),
              ),
              validator: (v) => _validateDouble(v, min: 1),
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
                  : Text(_isEdit ? 'Simpan Perubahan' : 'Tambah Lokasi'),
            ),
          ],
        ),
      ),
    );
  }
}
