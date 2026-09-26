import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/absensi.dart';
import '../../data/models/spt.dart';
import '../../data/repositories/absensi_repository.dart';
import '../../data/repositories/spt_repository.dart';
import '../../providers/auth_provider.dart';
import '../rekap/rekap_absensi_screen.dart';

/// Dashboard ringkas untuk Kepala Dinas (kebutuhan fungsional #13):
/// rekap kehadiran & status SPT seluruh PPL secara read-only.
class KepalaDinasHomeScreen extends StatefulWidget {
  const KepalaDinasHomeScreen({super.key});

  @override
  State<KepalaDinasHomeScreen> createState() => _KepalaDinasHomeScreenState();
}

class _KepalaDinasHomeScreenState extends State<KepalaDinasHomeScreen> {
  final _sptRepository = SptRepository();
  final _absensiRepository = AbsensiRepository();

  late Future<_DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DashboardData> _load() async {
    final sptList = await _sptRepository.findAll();
    final absensiList = await _absensiRepository.findAll();
    return _DashboardData(sptList: sptList, absensiList: absensiList);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Kepala Dinas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: FutureBuilder<_DashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final sptBerlangsung = data.sptList.where((s) => s.status == SptStatus.berlangsung).length;
          final tervalidasiHariIni = data.absensiList
              .where((a) => a.status == StatusAbsensi.tervalidasi && _isToday(a.waktu))
              .length;
          final menungguApproval = data.absensiList
              .where((a) =>
                  a.status == StatusAbsensi.tervalidasi && a.approvalStatus == ApprovalStatus.menunggu)
              .length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.05,
                children: [
                  _StatCard(
                    icon: Icons.assignment,
                    label: 'SPT Sedang Berlangsung',
                    value: '$sptBerlangsung',
                    color: Colors.green,
                  ),
                  _StatCard(
                    icon: Icons.verified,
                    label: 'Absen Tervalidasi Hari Ini',
                    value: '$tervalidasiHariIni',
                    color: Colors.blue,
                  ),
                  _StatCard(
                    icon: Icons.pending_actions,
                    label: 'Menunggu Persetujuan',
                    value: '$menungguApproval',
                    color: Colors.orange,
                  ),
                  _StatCard(
                    icon: Icons.people,
                    label: 'Total SPT Tercatat',
                    value: '${data.sptList.length}',
                    color: Colors.purple,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RekapAbsensiScreen()),
                ),
                icon: const Icon(Icons.bar_chart),
                label: const Text('Lihat Rekap Absensi Lengkap'),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _DashboardData {
  final List<Spt> sptList;
  final List<Absensi> absensiList;

  const _DashboardData({required this.sptList, required this.absensiList});
}
