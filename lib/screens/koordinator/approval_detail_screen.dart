import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/absensi.dart';
import '../../data/models/laporan.dart';
import '../../data/models/pegawai.dart';
import '../../data/models/spt.dart';
import '../../data/repositories/absensi_repository.dart';
import '../../data/repositories/laporan_repository.dart';
import '../../data/repositories/spt_repository.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/network_or_placeholder_image.dart';

/// Detail satu absensi yang menunggu persetujuan Koordinator, sekaligus
/// menampilkan laporan hasil kunjungan terkait (jika ada) sesuai kebutuhan
/// fungsional #10.
class ApprovalDetailScreen extends StatefulWidget {
  final Absensi absensi;
  final Pegawai pegawai;
  final Spt spt;

  const ApprovalDetailScreen({
    super.key,
    required this.absensi,
    required this.pegawai,
    required this.spt,
  });

  @override
  State<ApprovalDetailScreen> createState() => _ApprovalDetailScreenState();
}

class _ApprovalDetailScreenState extends State<ApprovalDetailScreen> {
  final _absensiRepository = AbsensiRepository();
  final _laporanRepository = LaporanRepository();
  final _sptRepository = SptRepository();
  final _catatanController = TextEditingController();

  late Future<Laporan?> _laporanFuture;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _laporanFuture = _laporanRepository.findBySpt(widget.spt.id!);
  }

  Future<void> _decide(ApprovalStatus status) async {
    final koordinator = context.read<AuthProvider>().currentUser!;
    setState(() => _saving = true);
    try {
      await _absensiRepository.setApproval(
        absensiId: widget.absensi.id!,
        status: status,
        approvedById: koordinator.id!,
        catatan: _catatanController.text.trim().isEmpty ? null : _catatanController.text.trim(),
      );
      // Keputusan koordinator langsung mencerminkan status SPT di dashboard PPL:
      // disetujui -> Selesai, ditolak -> Ditolak.
      await _sptRepository.updateStatus(
        widget.spt.id!,
        status == ApprovalStatus.disetujui ? SptStatus.selesai : SptStatus.ditolak,
      );
      // Tidak ada notifikasi lokal di sini lagi: PPL yang perlu diberi tahu
      // ada di device lain, bukan device koordinator ini. Lihat
      // AbsensiPollService, yang mendeteksi perubahan ini lewat polling di
      // device PPL dan memicu notifikasinya sendiri di sana.
      if (!mounted) return;
      Navigator.of(context).pop();
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
    final dateFormat = DateFormat('d MMM yyyy, HH:mm', 'id_ID');
    return Scaffold(
      appBar: AppBar(title: const Text('Tinjau Absensi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.pegawai.nama, style: Theme.of(context).textTheme.titleLarge),
                  Text(widget.pegawai.nip),
                  const Divider(height: 24),
                  Text(widget.spt.agenda, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('No. SPT: ${widget.spt.nomorSpt}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${widget.absensi.tipe.label} · ${widget.absensi.status.label}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Waktu: ${dateFormat.format(widget.absensi.waktu)}'),
                  Text('Jarak ke lokasi: ${widget.absensi.jarakMeter.toStringAsFixed(0)} m'),
                  Text(
                    'Kemiripan wajah: ${(widget.absensi.faceSimilarity * 100).toStringAsFixed(0)}%',
                  ),
                  if (widget.absensi.fotoPath != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: NetworkOrPlaceholderImage(path: widget.absensi.fotoPath, height: 180),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<Laporan?>(
            future: _laporanFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox.shrink();
              }
              final laporan = snapshot.data;
              if (laporan == null) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('PPL belum mengunggah laporan hasil kunjungan.'),
                  ),
                );
              }
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Laporan Hasil Kunjungan', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (laporan.fotoPath != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: NetworkOrPlaceholderImage(path: laporan.fotoPath, height: 180),
                        ),
                      const SizedBox(height: 8),
                      Text(laporan.catatan),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _catatanController,
            decoration: const InputDecoration(
              labelText: 'Catatan persetujuan (opsional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : () => _decide(ApprovalStatus.ditolak),
                  icon: const Icon(Icons.close, color: Colors.red),
                  label: const Text('Tolak', style: TextStyle(color: Colors.red)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saving ? null : () => _decide(ApprovalStatus.disetujui),
                  icon: const Icon(Icons.check),
                  label: const Text('Setujui'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
