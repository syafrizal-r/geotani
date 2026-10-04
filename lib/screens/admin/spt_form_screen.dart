import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/lokasi.dart';
import '../../data/models/pegawai.dart';
import '../../data/models/spt.dart';
import '../../data/repositories/lokasi_repository.dart';
import '../../data/repositories/pegawai_repository.dart';
import '../../data/repositories/spt_repository.dart';
import '../../services/api_client.dart';
import 'lokasi_form_screen.dart';

/// Form tambah/ubah SPT (Surat Perintah Tugas) untuk modul CRUD Admin Kepegawaian.
///
/// Lokasi tujuan dipilih dari data di tab Lokasi (koordinat dan radius ikut
/// dari sana). Tombol "Lokasi Baru" membuka form lokasi tanpa meninggalkan
/// form SPT, lalu lokasi barunya langsung terpilih.
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

  final _nomorSptController = TextEditingController();
  final _agendaController = TextEditingController();
  final _dateFormat = DateFormat('d MMM yyyy, HH:mm', 'id_ID');

  late Future<void> _optionsFuture;
  List<Pegawai> _pplList = [];
  List<Lokasi> _lokasiList = [];

  int? _pegawaiId;
  int? _lokasiId;
  late DateTime _tanggalMulai;
  late DateTime _tanggalSelesai;
  late SptStatus _status;

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _optionsFuture = _loadOptions();
    final existing = widget.existing;
    _pegawaiId = existing?.pegawaiId;
    _lokasiId = existing?.lokasiId;
    _tanggalMulai = existing?.tanggalMulai ?? DateTime.now();
    _tanggalSelesai = existing?.tanggalSelesai ?? DateTime.now().add(const Duration(hours: 8));
    _status = existing?.status ?? SptStatus.menunggu;
    if (existing != null) {
      _nomorSptController.text = existing.nomorSpt;
      _agendaController.text = existing.agenda;
    }
  }

  Future<void> _loadOptions() async {
    final (pegawai, lokasi) = await (_pegawaiRepository.findAll(), _lokasiRepository.findAll()).wait;
    _pplList = pegawai.where((p) => p.role == PegawaiRole.ppl).toList();
    _lokasiList = lokasi;
    // Pilihan lama yang datanya sudah tidak ada tidak boleh jadi nilai
    // dropdown (DropdownButton akan assert), jadi dikosongkan.
    if (!_pplList.any((p) => p.id == _pegawaiId)) _pegawaiId = null;
    if (!_lokasiList.any((l) => l.id == _lokasiId)) _lokasiId = null;
  }

  @override
  void dispose() {
    _nomorSptController.dispose();
    _agendaController.dispose();
    super.dispose();
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

  Future<void> _tambahLokasiBaru() async {
    final lokasi = await Navigator.of(context).push<Lokasi>(
      MaterialPageRoute(builder: (_) => const LokasiFormScreen()),
    );
    if (lokasi == null) return;
    setState(() {
      _lokasiList = [..._lokasiList, lokasi]..sort((a, b) => a.nama.compareTo(b.nama));
      _lokasiId = lokasi.id;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pegawaiId == null || _lokasiId == null) {
      setState(() => _error = _pegawaiId == null ? 'PPL wajib dipilih' : 'Lokasi tujuan wajib dipilih');
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
      final spt = Spt(
        id: widget.existing?.id,
        nomorSpt: _nomorSptController.text.trim(),
        pegawaiId: _pegawaiId!,
        lokasiId: _lokasiId!,
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
      body: FutureBuilder<void>(
        future: _optionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Gagal memuat data PPL/lokasi:\n${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => setState(() {
                        _optionsFuture = _loadOptions();
                      }),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
            );
          }
          final selectedLokasi = _lokasiList.where((l) => l.id == _lokasiId).firstOrNull;

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
                  items: _pplList
                      .map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(
                              p.isEnrolled ? p.nama : '${p.nama} (belum daftar wajah)',
                              overflow: TextOverflow.ellipsis,
                            ),
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
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        // initialValue hanya dibaca saat field dibuat; key ikut
                        // berubah supaya lokasi yang baru ditambahkan langsung terpilih.
                        key: ValueKey('lokasi-$_lokasiId-${_lokasiList.length}'),
                        initialValue: _lokasiId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Lokasi Tujuan', border: OutlineInputBorder()),
                        hint: Text(_lokasiList.isEmpty ? 'Belum ada lokasi' : 'Pilih lokasi'),
                        items: _lokasiList
                            .map((l) => DropdownMenuItem(
                                  value: l.id,
                                  child: Text(l.nama, overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _lokasiId = v),
                        validator: (v) => v == null ? 'Lokasi tujuan wajib dipilih' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: IconButton.filledTonal(
                        tooltip: 'Lokasi Baru',
                        onPressed: _tambahLokasiBaru,
                        icon: const Icon(Icons.add_location_alt_outlined),
                      ),
                    ),
                  ],
                ),
                if (selectedLokasi != null)
                  Card(
                    margin: const EdgeInsets.only(top: 8),
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.place_outlined),
                      title: Text(selectedLokasi.alamat),
                      subtitle: Text(
                        '${selectedLokasi.latitude.toStringAsFixed(6)}, ${selectedLokasi.longitude.toStringAsFixed(6)}'
                        ' · Radius ${selectedLokasi.radiusMeter.toStringAsFixed(0)} m',
                      ),
                    ),
                  )
                else if (_lokasiList.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Tambahkan lokasi dulu di tab Lokasi, atau tekan tombol + di samping.'),
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
