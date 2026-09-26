import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/absensi.dart';
import '../../data/models/rekap_row.dart';
import '../../data/repositories/absensi_repository.dart';
import '../../data/repositories/pegawai_repository.dart';
import '../../data/repositories/spt_repository.dart';
import '../../services/rekap_export_service.dart';

/// Rekap absensi (kebutuhan fungsional #11).
///
/// Diakses oleh Koordinator Penyuluh dan Kepala Dinas untuk melihat rekap
/// seluruh PPL ([pegawaiId] null), atau oleh PPL lewat tab Rekap di home
/// masing-masing untuk melihat rekap miliknya sendiri saja ([pegawaiId] diisi).
class RekapAbsensiScreen extends StatefulWidget {
  final int? pegawaiId;

  const RekapAbsensiScreen({super.key, this.pegawaiId});

  @override
  State<RekapAbsensiScreen> createState() => _RekapAbsensiScreenState();
}

class _RekapAbsensiScreenState extends State<RekapAbsensiScreen> {
  final _absensiRepository = AbsensiRepository();
  final _pegawaiRepository = PegawaiRepository();
  final _sptRepository = SptRepository();
  final _exportService = RekapExportService();

  late Future<List<RekapRow>> _future;
  DateTimeRange? _periodeFilter;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<RekapRow>> _load() async {
    final absensiList = await _absensiRepository.findAll();
    final pegawaiList = await _pegawaiRepository.findAll();
    final sptList = await _sptRepository.findAll();

    final pegawaiMap = {for (final p in pegawaiList) p.id: p};
    final sptMap = {for (final s in sptList) s.id: s};

    return absensiList
        .where((a) =>
            (widget.pegawaiId == null || a.pegawaiId == widget.pegawaiId) &&
            pegawaiMap[a.pegawaiId] != null &&
            sptMap[a.sptId] != null)
        .map((a) => RekapRow(absensi: a, pegawai: pegawaiMap[a.pegawaiId]!, spt: sptMap[a.sptId]!))
        .toList();
  }

  List<RekapRow> _applyFilter(List<RekapRow> rows) {
    final period = _periodeFilter;
    if (period == null) return rows;
    final endExclusive = period.end.add(const Duration(days: 1));
    return rows
        .where((r) => !r.absensi.waktu.isBefore(period.start) && r.absensi.waktu.isBefore(endExclusive))
        .toList();
  }

  Future<void> _pickPeriode() async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _periodeFilter,
    );
    if (result == null) return;
    setState(() {
      _periodeFilter = result;
    });
  }

  void _clearPeriode() {
    setState(() {
      _periodeFilter = null;
    });
  }

  Future<void> _export(List<RekapRow> rows, {required bool asPdf}) async {
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data untuk diexport.')),
      );
      return;
    }

    setState(() {
      _exporting = true;
    });

    try {
      final file = asPdf
          ? await _exportService.exportToPdf(rows, range: _periodeFilter)
          : await _exportService.exportToExcel(rows, range: _periodeFilter);

      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Rekap Absensi GeoTani',
          text: 'Rekap Absensi GeoTani (${_periodeFilter == null ? 'seluruh periode' : DateFormat('d MMM yyyy', 'id_ID').format(_periodeFilter!.start)} - ${_periodeFilter == null ? '' : DateFormat('d MMM yyyy', 'id_ID').format(_periodeFilter!.end)})',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat file export: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
        });
      }
    }
  }

  void _showExportSheet(List<RekapRow> rows) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Export Rekap Absensi'),
          children: [
            SimpleDialogOption(
              onPressed: () {
                Navigator.of(context).pop();
                _export(rows, asPdf: true);
              },
              child: const Row(
                children: [
                  Icon(Icons.picture_as_pdf_outlined, color: Colors.red),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Export sebagai PDF'),
                        Text(
                          'Cocok untuk dicetak atau dilampirkan ke laporan',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.of(context).pop();
                _export(rows, asPdf: false);
              },
              child: const Row(
                children: [
                  Icon(Icons.grid_on_outlined, color: Colors.green),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Export sebagai Excel (.xlsx)'),
                        Text(
                          'Cocok untuk diolah lebih lanjut',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pegawaiId != null ? 'Rekap Absensi Saya' : 'Rekap Absensi'),
        actions: [
          IconButton(
            tooltip: 'Filter periode',
            onPressed: _pickPeriode,
            icon: Icon(Icons.filter_alt, color: _periodeFilter != null ? Theme.of(context).colorScheme.primary : null),
          ),
          FutureBuilder<List<RekapRow>>(
            future: _future,
            builder: (context, snapshot) {
              final rows = _applyFilter(snapshot.data ?? []);
              return IconButton(
                tooltip: 'Export',
                onPressed: _exporting || snapshot.connectionState != ConnectionState.done
                    ? null
                    : () => _showExportSheet(rows),
                icon: _exporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.ios_share),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<RekapRow>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = _applyFilter(snapshot.data ?? []);

          final lolosSistem = rows.where((r) => r.absensi.status == StatusAbsensi.tervalidasi);
          final ditolakSistem = rows.length - lolosSistem.length;
          final disetujui =
              lolosSistem.where((r) => r.absensi.approvalStatus == ApprovalStatus.disetujui).length;
          final ditolakKoordinator =
              lolosSistem.where((r) => r.absensi.approvalStatus == ApprovalStatus.ditolak).length;
          final menunggu =
              lolosSistem.where((r) => r.absensi.approvalStatus == ApprovalStatus.menunggu).length;

          final dateFormat = DateFormat('d MMM yyyy, HH:mm', 'id_ID');

          return Column(
            children: [
              if (_periodeFilter != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      Icon(Icons.date_range, size: 16, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${DateFormat('d MMM yyyy', 'id_ID').format(_periodeFilter!.start)} - ${DateFormat('d MMM yyyy', 'id_ID').format(_periodeFilter!.end)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: _clearPeriode,
                        child: const Text('Hapus filter'),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _StatChip(label: 'Disetujui', value: disetujui, color: Colors.green),
                    const SizedBox(width: 6),
                    _StatChip(
                      label: 'Ditolak Koordinator',
                      value: ditolakKoordinator,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 6),
                    _StatChip(label: 'Menunggu Approval', value: menunggu, color: Colors.orange),
                    const SizedBox(width: 6),
                    _StatChip(label: 'Ditolak Sistem', value: ditolakSistem, color: Colors.grey),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: rows.isEmpty
                    ? const Center(child: Text('Belum ada data absensi.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          final ok = row.absensi.status == StatusAbsensi.tervalidasi;
                          return Card(
                            child: ListTile(
                              leading: Icon(
                                ok ? Icons.check_circle : Icons.cancel,
                                color: ok ? Colors.green : Colors.red,
                              ),
                              title: Text('${row.pegawai.nama} · ${row.absensi.tipe.label}'),
                              subtitle: Text(
                                '${row.spt.agenda}\n'
                                '${dateFormat.format(row.absensi.waktu)} · ${row.absensi.status.label}'
                                '${ok ? ' · ${row.absensi.approvalStatus.label}' : ''}',
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Text('$value', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: color), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
