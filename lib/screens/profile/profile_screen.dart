import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/pegawai.dart';
import '../../providers/auth_provider.dart';
import 'enroll_face_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) {
      // Sempat ter-render sekali lagi di tengah proses logout (rute ini
      // dipop belakangan, bukan langsung), sebelum akhirnya dihapus dari
      // stack navigasi — tampilkan kosong saja, jangan crash.
      return const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F6F3),
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, size: 56, color: Color(0xFF2E7D32)),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              user.nama,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          Center(
            child: Text(user.role.label, style: const TextStyle(color: Colors.black54)),
          ),
          const SizedBox(height: 24),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('NIP'),
                  subtitle: Text(user.nip),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.account_circle_outlined),
                  title: const Text('Username'),
                  subtitle: Text(user.username),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    user.isEnrolled ? Icons.verified_user : Icons.warning_amber,
                    color: user.isEnrolled ? const Color(0xFF2E7D32) : Colors.orange,
                  ),
                  title: const Text('Wajah Referensi'),
                  subtitle: Text(user.isEnrolled ? 'Sudah terdaftar' : 'Belum terdaftar'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.face_retouching_natural),
            label: Text(user.isEnrolled ? 'Perbarui Wajah Referensi' : 'Daftarkan Wajah Referensi'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EnrollFaceScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red[600]),
            icon: const Icon(Icons.logout),
            label: const Text('Keluar'),
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Keluar')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      // Keluar dulu dari route Profil (yang masih watch currentUser) sebelum
      // logout menyetel currentUser ke null, agar tidak rebuild dengan user null.
      Navigator.of(context).popUntil((route) => route.isFirst);
      context.read<AuthProvider>().logout();
    }
  }
}
