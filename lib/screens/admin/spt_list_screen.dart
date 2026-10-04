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
import 'admin_list_widgets.dart';
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
  String _query = '';
  SptStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_SptItem>> _load() async {
    // Tiga request paralel lalu digabung di sini, bukan 2 request per SPT.
    final (sptList, pegawaiList, lokasiList) = await (
      _sptRepository.findAll(),
      _pegawaiRepository.findAll(),
      _lokasiRepository.findAll(),
    ).wait;
    final pegawaiById = {for (final p in pegawaiList) p.id: p};
    final lokasiById = {for (final l in lokasiList) l.id: l};
    return [
      for (final spt in sptList)
        _SptItem(spt: spt, pegawai: pegawaiById[spt.pegawaiId], lokasi: lokasiById[spt.lokasiId]),
    ];
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
    try {
      final absensi = await _absensiRepository.findBySpt(spt.id!);
      final laporan = await _laporanRepository.findBySpt(spt.id!);
      if (absensi.isNotEmpty || laporan != null) {
        _showMessage('Tidak dapat menghapus SPT "${spt.nomorSpt}" karena sudah memiliki riwayat absensi/laporan.');
        return;
      }
      final confirmed = await _confirmDelete(spt.nomorSpt);
      if (confirmed != true) return;
      await _sptRepository.delete(spt.id!);
      _showMessage('SPT "${spt.nomorSpt}" dihapus.');
      _refresh();
    } catch (e) {
      _showMessage(e.toString());
    }
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
    if (!mounted) return;
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

  bool _matches(_SptItem item) {
    if (_statusFilter != null && item.spt.status != _statusFilter) return false;
    if (_query.isEmpty) return true;
    final text = '${item.spt.nomorSpt} ${item.spt.agenda} ${item.pegawai?.nama ?? ''} ${item.lokasi?.nama ?? ''}';
    return text.toLowerCase().contains(_query);
  }

  Widget _statusChips(List<_SptItem> all) {
    int count(SptStatus? s) => all.where((i) => s == null || i.spt.status == s).length;
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final s in <SptStatus?>[null, ...SptStatus.values])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('${s?.label ?? 'Semua'} (${count(s)})'),
                selected: _statusFilter == s,
                onSelected: (_) => setState(() => _statusFilter = s),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          AdminSearchField(
            hintText: 'Cari no. SPT, agenda, PPL, lokasi',
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<_SptItem>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return AdminListMessage('Gagal memuat data SPT:\n${snapshot.error}', onRetry: _refresh);
                  }
                  final all = snapshot.data ?? [];
                  final items = all.where(_matches).toList();
                  return Column(
                    children: [
                      if (all.isNotEmpty) _statusChips(all),
                      Expanded(
                        child: items.isEmpty
                            ? AdminListMessage(all.isEmpty ? 'Belum ada data SPT.' : 'Tidak ada SPT yang cocok.')
                            : _buildList(items),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<_SptItem> items) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
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
                      Text(
                        '${_dateFormat.format(item.spt.tanggalMulai)} s.d. ${_dateFormat.format(item.spt.tanggalSelesai)}',
                      ),
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
  }
}
