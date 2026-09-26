import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../data/models/pegawai.dart';
import '../../data/models/spt.dart';
import '../../data/repositories/pegawai_repository.dart';
import '../../data/repositories/lokasi_repository.dart';
import '../../data/models/lokasi.dart';
import '../../data/repositories/spt_repository.dart';
import '../../services/api_client.dart';
import '../../services/location_service.dart';

/// Form tambah/ubah SPT (Surat Perintah Tugas) untuk modul CRUD Admin Kepegawaian.
///
/// Lokasi tujuan diisi manual (bukan memilih dari lokasi yang sudah ada) dan
/// titik koordinatnya bisa langsung diambil dari GPS perangkat.
class SptFormScreen extends StatefulWidget {
  final Spt? existing;

  const SptFormScreen({super.key, this.existing});

  @override
  State<SptFormScreen> createState() => _SptFormScreenState();
}

class _SptFormScreenState extends State<SptFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sptRepository = SptRepository();
  final _pegawaiRepository = PegawaiRepository();
  final _lokasiRepository = LokasiRepository();
  final _locationService = LocationService();

  final _nomorSptController = TextEditingController();
  final _agendaController = TextEditingController();
  final _lokasiNamaController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _dateFormat = DateFormat('d MMM yyyy, HH:mm', 'id_ID');

  late Future<(List<Pegawai>, Lokasi?)> _optionsFuture;
  bool _prefilled = false;
  double? _existingRadius;

  int? _pegawaiId;
  late DateTime _tanggalMulai;
  late DateTime _tanggalSelesai;
  late SptStatus _status;

  bool _saving = false;
  bool _locating = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _optionsFuture = _loadOptions();
    final existing = widget.existing;
    _pegawaiId = existing?.pegawaiId;
    _tanggalMulai = existing?.tanggalMulai ?? DateTime.now();
    _tanggalSelesai = existing?.tanggalSelesai ?? DateTime.now().add(const Duration(hours: 8));
    _status = existing?.status ?? SptStatus.menunggu;
    if (existing != null) {
      _nomorSptController.text = existing.nomorSpt;
      _agendaController.text = existing.agenda;
    }
  }

  Future<(List<Pegawai>, Lokasi?)> _loadOptions() async {
    final pegawai = await _pegawaiRepository.findAll();
    final ppl = pegawai.where((p) => p.role == PegawaiRole.ppl).toList();
    final existing = widget.existing;
    final existingLokasi = existing == null ? null : await _lokasiRepository.findById(existing.lokasiId);
    return (ppl, existingLokasi);
  }

  @override
  void dispose() {
    _nomorSptController.dispose();
    _agendaController.dispose();
    _lokasiNamaController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
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

  Future<void> _pickDateTime({required bool isMulai}) async {
    final current = isMulai ? _tanggalMulai : _tanggalSelesai;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;
    final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isMulai) {
        _tanggalMulai = combined;
      } else {
        _tanggalSelesai = combined;
      }
    });
  }

  Future<void> _ambilTitikKoordinat() async {
    setState(() => _locating = true);
    try {
      final position = await _locationService.getCurrentPosition();
      setState(() {
        _latitudeController.text = position.latitude.toStringAsFixed(6);
        _longitudeController.text = position.longitude.toStringAsFixed(6);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pegawaiId == null) {
      setState(() => _error = 'PPL wajib dipilih');
      return;
    }
    if (!_tanggalSelesai.isAfter(_tanggalMulai)) {
      setState(() => _error = 'Tanggal selesai harus setelah tanggal mulai');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final lokasiNama = _lokasiNamaController.text.trim();
      final lokasi = Lokasi(
        id: widget.existing?.lokasiId,
        nama: lokasiNama,
        alamat: lokasiNama,
        latitude: double.parse(_latitudeController.text.trim()),
        longitude: double.parse(_longitudeController.text.trim()),
        radiusMeter: _existingRadius ?? AppConstants.defaultRadiusMeter,
      );

      final int lokasiId;
      if (_isEdit) {
        await _lokasiRepository.update(lokasi);
        lokasiId = widget.existing!.lokasiId;
      } else {
        lokasiId = await _lokasiRepository.insert(lokasi);
      }

      final spt = Spt(
        id: widget.existing?.id,
        nomorSpt: _nomorSptController.text.trim(),
        pegawaiId: _pegawaiId!,
        lokasiId: lokasiId,
        agenda: _agendaController.text.trim(),
        tanggalMulai: _tanggalMulai,
        tanggalSelesai: _tanggalSelesai,
        status: _status,
      );

      if (_isEdit) {
        await _sptRepository.update(spt);
      } else {
        await _sptRepository.insert(spt);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() {
        _error = e.statusCode == 409 ? 'Nomor SPT sudah digunakan.' : e.message;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Ubah SPT' : 'Tambah SPT')),
      body: FutureBuilder<(List<Pegawai>, Lokasi?)>(
        future: _optionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final (pplList, existingLokasi) = snapshot.data ?? (const <Pegawai>[], null);
          if (!_prefilled && existingLokasi != null) {
            _lokasiNamaController.text = existingLokasi.nama;
            _latitudeController.text = existingLokasi.latitude.toString();
            _longitudeController.text = existingLokasi.longitude.toString();
            _existingRadius = existingLokasi.radiusMeter;
            _prefilled = true;
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _nomorSptController,
                  decoration: const InputDecoration(labelText: 'No. SPT', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'No. SPT wajib diisi' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _pegawaiId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'PPL', border: OutlineInputBorder()),
                  items: pplList
                      .map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.nama, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _pegawaiId = v),
                  validator: (v) => v == null ? 'PPL wajib dipilih' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _agendaController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'SPT Dalam Rangka Apa',
                    hintText: 'mis. Pendampingan panen padi kelompok tani',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 24),
                Text(
                  'Lokasi Tujuan',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _lokasiNamaController,
                  decoration: const InputDecoration(
                    labelText: 'Lokasi Tujuan',
                    hintText: 'mis. Kelompok Tani Sido Makmur',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Lokasi tujuan wajib diisi' : null,
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _locating ? null : _ambilTitikKoordinat,
                  icon: _locating
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  label: Text(_locating ? 'Mengambil titik koordinat...' : 'Ambil Titik Koordinat Saat Ini'),
                ),
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tanggal Mulai'),
                  subtitle: Text(_dateFormat.format(_tanggalMulai)),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: () => _pickDateTime(isMulai: true),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tanggal Selesai'),
                  subtitle: Text(_dateFormat.format(_tanggalSelesai)),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: () => _pickDateTime(isMulai: false),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<SptStatus>(
                  initialValue: _status,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                  items: SptStatus.values
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s.label, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _status = v ?? _status),
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
                      : Text(_isEdit ? 'Simpan Perubahan' : 'Tambah SPT'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
