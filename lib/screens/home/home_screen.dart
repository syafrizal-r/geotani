import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/absensi.dart';
import '../../data/models/pegawai.dart';
import '../../data/models/spt.dart';
import '../../data/repositories/absensi_repository.dart';
import '../../data/repositories/spt_repository.dart';
import '../../providers/auth_provider.dart';
import '../../services/absensi_poll_service.dart';
import '../admin/admin_home_screen.dart';
import '../kepala_dinas/kepala_dinas_home_screen.dart';
import '../koordinator/koordinator_home_screen.dart';
import '../pengumuman/pengumuman_screen.dart';
import '../profile/enroll_face_screen.dart';
import '../profile/profile_screen.dart';
import '../rekap/rekap_absensi_screen.dart';
import '../spt/spt_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser!;

    switch (user.role) {
      case PegawaiRole.koordinator:
        return const KoordinatorHomeScreen();
      case PegawaiRole.kepalaDinas:
        return const KepalaDinasHomeScreen();
      case PegawaiRole.admin:
        return const AdminHomeScreen();
      case PegawaiRole.ppl:
        return const _PplDashboard();
    }
  }
}

enum _TodayStatus { belum, masuk, selesai }

class _PplHomeData {
  final List<Spt> sptList;
  final _TodayStatus status;
  const _PplHomeData({required this.sptList, required this.status});
}

class _PplDashboard extends StatefulWidget {
  const _PplDashboard();

  @override
  State<_PplDashboard> createState() => _PplDashboardState();
}

class _PplDashboardState extends State<_PplDashboard> {
  final _sptRepository = SptRepository();
  final _absensiRepository = AbsensiRepository();
  final _pollService = AbsensiPollService();
  late Future<_PplHomeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId != null) _pollService.startForPpl(userId);
  }

  @override
  void dispose() {
    _pollService.stop();
    super.dispose();
  }

  Future<_PplHomeData> _load() async {
    final user = context.read<AuthProvider>().currentUser!;
    final sptList = await _sptRepository.findByPegawai(user.id!);
    final absensi = await _absensiRepository.findByPegawai(user.id!);
    final today = DateTime.now();
    final absensiHariIni = absensi.where(
      (a) =>
          a.status == StatusAbsensi.tervalidasi &&
          a.waktu.year == today.year &&
          a.waktu.month == today.month &&
          a.waktu.day == today.day,
    );
    final hasCheckIn = absensiHariIni.any((a) => a.tipe == TipeAbsensi.checkIn);
    final hasCheckOut = absensiHariIni.any((a) => a.tipe == TipeAbsensi.checkOut);
    final status = hasCheckOut
        ? _TodayStatus.selesai
        : (hasCheckIn ? _TodayStatus.masuk : _TodayStatus.belum);
    return _PplHomeData(sptList: sptList, status: status);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Spt? _activeSpt(List<Spt> list) {
    for (final spt in list) {
      if (spt.status == SptStatus.berlangsung) return spt;
    }
    return null;
  }

  Future<void> _openAbsen(List<Spt> list) async {
    final active = _activeSpt(list);
    if (active == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada SPT yang sedang berlangsung saat ini.')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SptDetailScreen(sptId: active.id!)),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser!;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F6F3),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FutureBuilder<_PplHomeData>(
        future: _future,
        builder: (context, snapshot) {
          final list = snapshot.data?.sptList ?? const [];
          return _AbsenFab(onPressed: () => _openAbsen(list));
        },
      ),
      bottomNavigationBar: _BottomBar(
        onPengumuman: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PengumumanScreen()),
        ),
        onRekap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => RekapAbsensiScreen(pegawaiId: user.id)),
        ),
        onProfil: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_PplHomeData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final data =
                snapshot.data ?? const _PplHomeData(sptList: [], status: _TodayStatus.belum);
            final aktifCount = data.sptList.where((s) => s.status == SptStatus.berlangsung).length;

            return ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                _DashboardHeader(user: user),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!user.isEnrolled) ...[
                        _EnrollBanner(user: user, onDone: _refresh),
                        const SizedBox(height: 16),
                      ],
                      _InfoBanner(aktifCount: aktifCount),
                      const SizedBox(height: 16),
                      _StatusCard(status: data.status, onRefresh: _refresh),
                      const SizedBox(height: 24),
                      Text(
                        'Menu Utama',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _MenuTile(
                              icon: Icons.login,
                              label: 'Presensi Masuk',
                              color: const Color(0xFF2E7D32),
                              onTap: () => _openAbsen(data.sptList),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MenuTile(
                              icon: Icons.logout,
                              label: 'Presensi Keluar',
                              color: const Color(0xFFC62828),
                              onTap: () => _openAbsen(data.sptList),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Daftar SPT',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
                if (data.sptList.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Belum ada SPT yang ditugaskan kepada Anda.',
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        for (final spt in data.sptList) ...[
                          _SptCard(spt: spt),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final Pegawai user;
  const _DashboardHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF14532D), Color(0xFF2E7D32), Color(0xFF43A047)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selamat Datang',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      Text(
                        user.nama,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user.role.label,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                _HeaderIconButton(
                  icon: Icons.logout,
                  tooltip: 'Keluar',
                  onPressed: () => context.read<AuthProvider>().logout(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.badge_outlined, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text('NIP: ${user.nip}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  const _HeaderIconButton({required this.icon, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final int aktifCount;
  const _InfoBanner({required this.aktifCount});

  @override
  Widget build(BuildContext context) {
    final text = aktifCount > 0
        ? 'Anda memiliki $aktifCount SPT yang sedang berlangsung'
        : 'Tidak ada SPT yang sedang berlangsung saat ini';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFA726), Color(0xFFFB8C00)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final _TodayStatus status;
  final Future<void> Function() onRefresh;
  const _StatusCard({required this.status, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (status) {
      _TodayStatus.belum => (Icons.schedule, 'Belum Presensi', const Color(0xFF1E88E5)),
      _TodayStatus.masuk => (Icons.check_circle, 'Sudah Presensi Masuk', const Color(0xFF2E7D32)),
      _TodayStatus.selesai => (Icons.task_alt, 'Presensi Selesai', const Color(0xFF616161)),
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Status Hari Ini', style: TextStyle(color: Colors.black54)),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onRefresh,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F4F2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.refresh, size: 18, color: Color(0xFF2E7D32)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 10),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AbsenFab extends StatelessWidget {
  final VoidCallback onPressed;
  const _AbsenFab({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: FloatingActionButton(
        onPressed: onPressed,
        backgroundColor: const Color(0xFF2E7D32),
        elevation: 4,
        shape: const CircleBorder(),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_turned_in, color: Colors.white, size: 18),
            SizedBox(height: 2),
            Text(
              'Absen SPT',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final VoidCallback onPengumuman;
  final VoidCallback onRekap;
  final VoidCallback onProfil;
  const _BottomBar({required this.onPengumuman, required this.onRekap, required this.onProfil});

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: Colors.white,
      child: SizedBox(
        height: 64,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            const _NavItem(icon: Icons.home, label: 'Home', active: true),
            _NavItem(icon: Icons.campaign_outlined, label: 'Pengumuman', onTap: onPengumuman),
            const SizedBox(width: 48),
            _NavItem(icon: Icons.bar_chart, label: 'Rekap', onTap: onRekap),
            _NavItem(icon: Icons.person_outline, label: 'Profile', onTap: onProfil),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;
  const _NavItem({required this.icon, required this.label, this.active = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF2E7D32) : Colors.black45;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _SptCard extends StatelessWidget {
  final Spt spt;
  const _SptCard({required this.spt});

  Color _statusColor() {
    switch (spt.status) {
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
    final dateFormat = DateFormat('d MMM yyyy, HH:mm', 'id_ID');
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        title: Text(spt.agenda, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('No. SPT: ${spt.nomorSpt}'),
              Text(dateFormat.format(spt.tanggalMulai)),
            ],
          ),
        ),
        trailing: Chip(
          label: Text(spt.status.label, style: const TextStyle(color: Colors.white, fontSize: 11)),
          backgroundColor: _statusColor(),
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => SptDetailScreen(sptId: spt.id!)),
          );
        },
      ),
    );
  }
}

class _EnrollBanner extends StatelessWidget {
  final Pegawai user;
  final VoidCallback onDone;
  const _EnrollBanner({required this.user, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      backgroundColor: Colors.amber[100],
      content: const Text(
        'Anda belum mendaftarkan wajah referensi. Absen tidak dapat dilakukan sebelum enrolment wajah.',
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EnrollFaceScreen()),
            );
            onDone();
          },
          child: const Text('Daftarkan Sekarang'),
        ),
      ],
    );
  }
}

