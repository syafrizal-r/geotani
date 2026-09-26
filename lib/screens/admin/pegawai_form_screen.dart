import 'package:flutter/material.dart';

import '../../data/models/pegawai.dart';
import '../../data/repositories/pegawai_repository.dart';
import '../../services/api_client.dart';
import '../../utils/password_hasher.dart';

/// Form tambah/ubah pegawai untuk modul CRUD Admin Kepegawaian.
class PegawaiFormScreen extends StatefulWidget {
  final Pegawai? existing;

  const PegawaiFormScreen({super.key, this.existing});

  @override
  State<PegawaiFormScreen> createState() => _PegawaiFormScreenState();
}

class _PegawaiFormScreenState extends State<PegawaiFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pegawaiRepository = PegawaiRepository();

  final _nipController = TextEditingController();
  final _namaController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  late PegawaiRole _role;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _role = existing?.role ?? PegawaiRole.ppl;
    if (existing != null) {
      _nipController.text = existing.nip;
      _namaController.text = existing.nama;
      _usernameController.text = existing.username;
    }
  }

  @override
  void dispose() {
    _nipController.dispose();
    _namaController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final passwordInput = _passwordController.text.trim();
      // null saat edit tanpa ganti password -> repository/server tidak
      // mengubah password_hash yang sudah tersimpan.
      final passwordHash = passwordInput.isNotEmpty ? PasswordHasher.hash(passwordInput) : null;

      final pegawai = Pegawai(
        id: widget.existing?.id,
        nip: _nipController.text.trim(),
        nama: _namaController.text.trim(),
        username: _usernameController.text.trim(),
        passwordHash: passwordHash,
        role: _role,
        faceEmbedding: widget.existing?.faceEmbedding,
      );

      if (_isEdit) {
        await _pegawaiRepository.update(pegawai);
      } else {
        await _pegawaiRepository.insert(pegawai);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() {
        _error = e.statusCode == 409 ? 'NIP atau username sudah digunakan pegawai lain.' : e.message;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Ubah Pegawai' : 'Tambah Pegawai')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nipController,
              decoration: const InputDecoration(labelText: 'NIP', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'NIP wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _namaController,
              decoration: const InputDecoration(labelText: 'Nama', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Username wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: _isEdit ? 'Password baru (kosongkan jika tidak diubah)' : 'Password',
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                if (_isEdit) return null;
                return (v == null || v.isEmpty) ? 'Password wajib diisi' : null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PegawaiRole>(
              initialValue: _role,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Peran', border: OutlineInputBorder()),
              items: PegawaiRole.values
                  .map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(r.label, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _role = v ?? _role),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_isEdit ? 'Simpan Perubahan' : 'Tambah Pegawai'),
            ),
          ],
        ),
      ),
    );
  }
}
