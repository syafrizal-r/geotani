import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/absensi.dart';
import '../../data/models/pegawai.dart';
import '../../data/models/spt.dart';
import '../../data/repositories/absensi_repository.dart';
import '../../data/repositories/pegawai_repository.dart';
import '../../data/repositories/spt_repository.dart';
import '../../providers/auth_provider.dart';
import '../../services/absensi_poll_service.dart';
import '../rekap/rekap_absensi_screen.dart';
import 'approval_detail_screen.dart';

class KoordinatorHomeScreen extends StatefulWidget {
  const KoordinatorHomeScreen({super.key});

  @override
  State<KoordinatorHomeScreen> createState() => _KoordinatorHomeScreenState();
}

class _KoordinatorHomeScreenState extends State<KoordinatorHomeScreen> {
  final _absensiRepository = AbsensiRepository();
  final _pegawaiRepository = PegawaiRepository();
  final _sptRepository = SptRepository();
  final _pollService = AbsensiPollService();

  late Future<List<_PendingItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _pollService.startForKoordinator();
  }

  @override
  void dispose() {
    _pollService.stop();
    super.dispose();
  }

  Future<List<_PendingItem>> _load() async {
    final pending = await _absensiRepository.findPendingApproval();
    final items = <_PendingItem>[];
    for (final absensi in pending) {
      final pegawai = await _pegawaiRepository.findById(absensi.pegawaiId);
      final spt = await _sptRepository.findById(absensi.sptId);
      if (pegawai != null && spt != null) {
        items.add(_PendingItem(absensi: absensi, pegawai: pegawai, spt: spt));
      }
    }
    return items;
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
      appBar: AppBar(
        title: const Text('Persetujuan Absensi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Rekap Absensi',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RekapAbsensiScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<_PendingItem>>(
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
                    child: Text(
                      'Tidak ada absensi yang menunggu persetujuan saat ini.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }
            final dateFormat = DateFormat('d MMM yyyy, HH:mm', 'id_ID');
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text('${item.pegawai.nama} · ${item.absensi.tipe.label}'),
                    subtitle: Text(
                      '${item.spt.agenda}\n${dateFormat.format(item.absensi.waktu)}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ApprovalDetailScreen(
                            absensi: item.absensi,
                            pegawai: item.pegawai,
                            spt: item.spt,
                          ),
                        ),
                      );
                      _refresh();
                    },
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

class _PendingItem {
  final Absensi absensi;
  final Pegawai pegawai;
  final Spt spt;

  const _PendingItem({required this.absensi, required this.pegawai, required this.spt});
}
