import 'package:flutter/material.dart';

import '../../data/models/lokasi.dart';
import '../../data/repositories/lokasi_repository.dart';
import '../../data/repositories/spt_repository.dart';
import 'admin_list_widgets.dart';
import 'lokasi_form_screen.dart';

/// Tab CRUD Lokasi pada modul Admin Kepegawaian.
class LokasiListScreen extends StatefulWidget {
  const LokasiListScreen({super.key});

  @override
  State<LokasiListScreen> createState() => _LokasiListScreenState();
}

class _LokasiListScreenState extends State<LokasiListScreen> {
  final _lokasiRepository = LokasiRepository();
  final _sptRepository = SptRepository();

  late Future<List<Lokasi>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Lokasi>> _load() => _lokasiRepository.findAll();

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _openForm({Lokasi? existing}) async {
    final saved = await Navigator.of(context).push<Lokasi>(
      MaterialPageRoute(builder: (_) => LokasiFormScreen(existing: existing)),
    );
    if (saved != null) _refresh();
  }

  Future<void> _delete(Lokasi lokasi) async {
    try {
      final hasSpt = await _sptRepository.existsForLokasi(lokasi.id!);
      if (hasSpt) {
        _showMessage('Tidak dapat menghapus "${lokasi.nama}" karena masih memiliki SPT terkait.');
        return;
      }
      final confirmed = await _confirmDelete(lokasi.nama);
      if (confirmed != true) return;
      await _lokasiRepository.delete(lokasi.id!);
      _showMessage('Lokasi "${lokasi.nama}" dihapus.');
      _refresh();
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<bool?> _confirmDelete(String nama) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Lokasi'),
        content: Text('Yakin ingin menghapus lokasi "$nama"?'),
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
            hintText: 'Cari nama atau alamat lokasi',
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<Lokasi>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return AdminListMessage(
                      'Gagal memuat data lokasi:\n${snapshot.error}',
                      onRetry: _refresh,
                    );
                  }
                  final all = snapshot.data ?? [];
                  final items = all
                      .where((l) => _query.isEmpty || '${l.nama} ${l.alamat}'.toLowerCase().contains(_query))
                      .toList();
                  if (items.isEmpty) {
                    return AdminListMessage(all.isEmpty ? 'Belum ada data lokasi.' : 'Tidak ada lokasi yang cocok.');
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final lokasi = items[index];
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.place_outlined)),
                          title: Text(lokasi.nama),
                          subtitle: Text(
                            '${lokasi.alamat}\n'
                            '${lokasi.latitude.toStringAsFixed(6)}, ${lokasi.longitude.toStringAsFixed(6)}'
                            ' · Radius ${lokasi.radiusMeter.toStringAsFixed(0)} m',
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _openForm(existing: lokasi),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _delete(lokasi),
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
          ),
        ],
      ),
    );
  }
}
