import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/pegawai.dart';
import '../../data/repositories/pegawai_repository.dart';
import '../../data/repositories/spt_repository.dart';
import '../../providers/auth_provider.dart';
import 'pegawai_form_screen.dart';

/// Tab CRUD Pegawai pada modul Admin Kepegawaian.
class PegawaiListScreen extends StatefulWidget {
  const PegawaiListScreen({super.key});

  @override
  State<PegawaiListScreen> createState() => _PegawaiListScreenState();
}

class _PegawaiListScreenState extends State<PegawaiListScreen> {
  final _pegawaiRepository = PegawaiRepository();
  final _sptRepository = SptRepository();

  late Future<List<Pegawai>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Pegawai>> _load() => _pegawaiRepository.findAll();

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _openForm({Pegawai? existing}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PegawaiFormScreen(existing: existing)),
    );
    if (saved == true) _refresh();
  }

  Future<void> _delete(Pegawai pegawai) async {
    final currentUserId = context.read<AuthProvider>().currentUser?.id;
    if (pegawai.id == currentUserId) {
      _showMessage('Tidak dapat menghapus akun yang sedang digunakan.');
      return;
    }
    final sptList = await _sptRepository.findByPegawai(pegawai.id!);
    if (sptList.isNotEmpty) {
      _showMessage('Tidak dapat menghapus "${pegawai.nama}" karena masih memiliki SPT terkait.');
      return;
    }
    final confirmed = await _confirmDelete(pegawai.nama);
    if (confirmed != true) return;
    await _pegawaiRepository.delete(pegawai.id!);
    _refresh();
  }

  Future<bool?> _confirmDelete(String nama) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Pegawai'),
        content: Text('Yakin ingin menghapus pegawai "$nama"?'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Pegawai>>(
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
                    child: Text('Belum ada data pegawai.', textAlign: TextAlign.center),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final pegawai = items[index];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(pegawai.nama),
                    subtitle: Text('NIP: ${pegawai.nip} · ${pegawai.role.label}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _openForm(existing: pegawai),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(pegawai),
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
