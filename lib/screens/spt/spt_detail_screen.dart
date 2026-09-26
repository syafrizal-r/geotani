import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/absensi.dart';
import '../../data/models/laporan.dart';
import '../../data/models/lokasi.dart';
import '../../data/models/pegawai.dart';
import '../../data/models/spt.dart';
import '../../data/repositories/absensi_repository.dart';
import '../../data/repositories/laporan_repository.dart';
import '../../data/repositories/lokasi_repository.dart';
import '../../data/repositories/spt_repository.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/network_or_placeholder_image.dart';
import '../absen/checkin_screen.dart';
import '../laporan/laporan_form_screen.dart';

class SptDetailScreen extends StatefulWidget {
  final int sptId;
  const SptDetailScreen({super.key, required this.sptId});

  @override
  State<SptDetailScreen> createState() => _SptDetailScreenState();
}

class _SptDetailScreenState extends State<SptDetailScreen> {
  final _sptRepository = SptRepository();
  final _lokasiRepository = LokasiRepository();
  final _absensiRepository = AbsensiRepository();
  final _laporanRepository = LaporanRepository();

  late Future<_SptDetailData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_SptDetailData> _load() async {
    final spt = await _sptRepository.findById(widget.sptId);
    final lokasi = await _lokasiRepository.findById(spt!.lokasiId);
    final absensi = await _absensiRepository.findBySpt(widget.sptId);
    final laporan = await _laporanRepository.findBySpt(widget.sptId);
    return _SptDetailData(spt: spt, lokasi: lokasi!, absensi: absensi, laporan: laporan);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Surat Perintah Tugas')),
      body: FutureBuilder<_SptDetailData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final hasCheckin = data.absensi.any(
            (a) => a.tipe == TipeAbsensi.checkIn && a.status == StatusAbsensi.tervalidasi,
          );
          final hasCheckout = data.absensi.any(
            (a) => a.tipe == TipeAbsensi.checkOut && a.status == StatusAbsensi.tervalidasi,
          );
          final dateFormat = DateFormat('d MMM yyyy, HH:mm', 'id_ID');
          final user = context.watch<AuthProvider>().currentUser!;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data.spt.agenda, style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text('No. SPT: ${data.spt.nomorSpt}'),
                        Text(
                          '${dateFormat.format(data.spt.tanggalMulai)} s.d. '
                          '${dateFormat.format(data.spt.tanggalSelesai)}',
                        ),
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
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                data.lokasi.nama,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(data.lokasi.alamat),
                        const SizedBox(height: 4),
                        Text('Radius toleransi absen: ${data.lokasi.radiusMeter.toInt()} meter'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (data.absensi.isNotEmpty) ...[
                  Text('Riwayat Absensi', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...data.absensi.map((a) => _AbsensiTile(absensi: a, dateFormat: dateFormat)),
                  const SizedBox(height: 12),
                ],
                if (hasCheckin && user.role == PegawaiRole.ppl) ...[
                  Text('Laporan Hasil Kunjungan', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _LaporanCard(laporan: data.laporan),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: Icon(data.laporan == null ? Icons.note_add : Icons.edit_note),
                    label: Text(data.laporan == null ? 'Isi Laporan Kunjungan' : 'Perbarui Laporan'),
                    onPressed: () => _openLaporanForm(context, data),
                  ),
                  const SizedBox(height: 16),
                ],
                if (!user.isEnrolled)
                  const Card(
                    color: Color(0xFFFFF3E0),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Wajah referensi belum terdaftar. Daftarkan lewat menu Profil sebelum absen.',
                      ),
                    ),
                  )
                else if (!hasCheckin)
                  FilledButton.icon(
                    icon: const Icon(Icons.login),
                    label: const Text('Mulai Check-in'),
                    onPressed: () => _startAbsen(context, data, TipeAbsensi.checkIn),
                  )
                else if (!hasCheckout)
                  FilledButton.icon(
                    icon: const Icon(Icons.logout),
                    label: const Text('Check-out'),
                    onPressed: () => _startAbsen(context, data, TipeAbsensi.checkOut),
                  )
                else
                  const Card(
                    color: Color(0xFFE8F5E9),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Tugas ini sudah selesai (check-in & check-out tervalidasi).'),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _startAbsen(BuildContext context, _SptDetailData data, TipeAbsensi tipe) async {
    if (tipe == TipeAbsensi.checkOut && DateTime.now().isBefore(data.spt.tanggalSelesai)) {
      final lanjut = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Check-out Lebih Awal'),
          content: Text(
            'Jam tugas Anda berakhir pukul '
            '${DateFormat('HH:mm', 'id_ID').format(data.spt.tanggalSelesai)}, tapi Anda '
            'check-out sebelum waktu tersebut. Lanjutkan check-out lebih awal?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Tetap Check-out'),
            ),
          ],
        ),
      );
      if (lanjut != true || !mounted) return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CheckinScreen(spt: data.spt, lokasi: data.lokasi, tipe: tipe),
      ),
    );
    _refresh();
  }

  Future<void> _openLaporanForm(BuildContext context, _SptDetailData data) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LaporanFormScreen(spt: data.spt, existing: data.laporan),
      ),
    );
    if (saved == true) _refresh();
  }
}

class _LaporanCard extends StatelessWidget {
  final Laporan? laporan;
  const _LaporanCard({required this.laporan});

  @override
  Widget build(BuildContext context) {
    if (laporan == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('Belum ada laporan hasil kunjungan untuk tugas ini.'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (laporan!.fotoPath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: NetworkOrPlaceholderImage(path: laporan!.fotoPath, height: 160),
              ),
            const SizedBox(height: 8),
            Text(laporan!.catatan),
          ],
        ),
      ),
    );
  }
}

class _AbsensiTile extends StatelessWidget {
  final Absensi absensi;
  final DateFormat dateFormat;
  const _AbsensiTile({required this.absensi, required this.dateFormat});

  @override
  Widget build(BuildContext context) {
    final ok = absensi.status == StatusAbsensi.tervalidasi;
    return Card(
      child: ListTile(
        leading: Icon(
          ok ? Icons.check_circle : Icons.cancel,
          color: ok ? Colors.green : Colors.red,
        ),
        title: Text('${absensi.tipe.label} - ${absensi.status.label}'),
        subtitle: Text(
          '${dateFormat.format(absensi.waktu)}\n'
          'Jarak: ${absensi.jarakMeter.toStringAsFixed(0)} m · '
          'Kemiripan wajah: ${(absensi.faceSimilarity * 100).toStringAsFixed(0)}%'
          '${ok ? '\nPersetujuan atasan: ${absensi.approvalStatus.label}' : ''}',
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _SptDetailData {
  final Spt spt;
  final Lokasi lokasi;
  final List<Absensi> absensi;
  final Laporan? laporan;

  const _SptDetailData({
    required this.spt,
    required this.lokasi,
    required this.absensi,
    required this.laporan,
  });
}
