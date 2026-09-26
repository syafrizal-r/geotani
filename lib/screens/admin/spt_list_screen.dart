import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/lokasi.dart';
import '../../data/models/pegawai.dart';
import '../../data/models/spt.dart';
import '../../data/repositories/absensi_repository.dart';
import '../../data/repositories/laporan_repository.dart';
import '../../data/repositories/lokasi_repository.dart';
import '../../data/repositories/pegawai_repository.dart';
import '../../data/repositories/spt_repository.dart';
import 'spt_form_screen.dart';

class _SptItem {
  final Spt spt;
  final Pegawai? pegawai;
  final Lokasi? lokasi;
  const _SptItem({required this.spt, required this.pegawai, required this.lokasi});
}

/// Tab CRUD SPT (Surat Perintah Tugas) pada modul Admin Kepegawaian.
class SptListScreen extends StatefulWidget {
  const SptListScreen({super.key});

  @override
  State<SptListScreen> createState() => _SptListScreenState();
}

class _SptListScreenState extends State<SptListScreen> {
  final _sptRepository = SptRepository();
  final _pegawaiRepository = PegawaiRepository();
  final _lokasiRepository = LokasiRepository();
  final _absensiRepository = AbsensiRepository();
  final _laporanRepository = LaporanRepository();
  final _dateFormat = DateFormat('d MMM yyyy, HH:mm', 'id_ID');

  late Future<List<_SptItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_SptItem>> _load() async {
    final sptList = await _sptRepository.findAll();
    final items = <_SptItem>[];
    for (final spt in sptList) {
      final pegawai = await _pegawaiRepository.findById(spt.pegawaiId);
      final lokasi = await _lokasiRepository.findById(spt.lokasiId);
      items.add(_SptItem(spt: spt, pegawai: pegawai, lokasi: lokasi));
    }
    return items;
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _openForm({Spt? existing}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SptFormScreen(existing: existing)),
    );
    if (saved == true) _refresh();
  }

  Future<void> _delete(Spt spt) async {
    final absensi = await _absensiRepository.findBySpt(spt.id!);
    final laporan = await _laporanRepository.findBySpt(spt.id!);
    if (absensi.isNotEmpty || laporan != null) {
      _showMessage('Tidak dapat menghapus SPT "${spt.nomorSpt}" karena sudah memiliki riwayat absensi/laporan.');
      return;
    }
    final confirmed = await _confirmDelete(spt.nomorSpt);
    if (confirmed != true) return;
    await _sptRepository.delete(spt.id!);
    _refresh();
  }

  Future<bool?> _confirmDelete(String nomorSpt) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus SPT'),
        content: Text('Yakin ingin menghapus SPT "$nomorSpt"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Hapus')),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Color _statusColor(SptStatus status) {
    switch (status) {
      case SptStatus.berlangsung:
        return Colors.green;
      case SptStatus.menunggu:
        return Colors.orange;
      case SptStatus.selesai:
        return Colors.grey;
      case SptStatus.ditolak:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<_SptItem>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('Belum ada data SPT.', textAlign: TextAlign.center),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.spt.agenda,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Chip(
                              label: Text(
                                item.spt.status.label,
                                style: const TextStyle(color: Colors.white, fontSize: 11),
                              ),
                              backgroundColor: _statusColor(item.spt.status),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('No. SPT: ${item.spt.nomorSpt}'),
                              Text('PPL: ${item.pegawai?.nama ?? '-'}'),
                              Text('Lokasi: ${item.lokasi?.nama ?? '-'}'),
                              Text(_dateFormat.format(item.spt.tanggalMulai)),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _openForm(existing: item.spt),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(item.spt),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
