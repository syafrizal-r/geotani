import 'package:flutter/material.dart';

import '../../core/api_config.dart';
import '../../services/api_client.dart';

/// Layar untuk mengisi alamat IP:port server GeoTani lokal (LAN). Ditampilkan
/// otomatis saat pertama kali app dibuka (belum ada alamat tersimpan), dan
/// bisa dibuka lagi dari LoginScreen untuk ganti alamat (mis. pindah WiFi).
class ServerSettingsScreen extends StatefulWidget {
  final VoidCallback? onSaved;

  const ServerSettingsScreen({super.key, this.onSaved});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  final _controller = TextEditingController();
  bool _testing = false;
  bool _saving = false;
  String? _testResult;
  bool _testOk = false;

  @override
  void initState() {
    super.initState();
    if (ApiConfig.instance.isConfigured) {
      _controller.text = ApiConfig.instance.baseUrl;
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final previous = ApiConfig.instance.isConfigured ? ApiConfig.instance.baseUrl : null;
    try {
      await ApiConfig.instance.setBaseUrl(_controller.text);
      final result = await ApiClient.instance.get('/api/health');
      final ok = result is Map && result['status'] == 'ok';
      setState(() {
        _testOk = ok;
        _testResult = ok
            ? 'Berhasil terhubung ke server.'
            : 'Server merespons tapi format tidak dikenali.';
      });
    } on FormatException catch (e) {
      setState(() {
        _testOk = false;
        _testResult = e.message;
      });
    } catch (e) {
      setState(() {
        _testOk = false;
        _testResult = 'Gagal terhubung: $e';
      });
    } finally {
      if (previous != null) {
        // Jangan diam-diam mengganti konfigurasi tersimpan hanya karena tes;
        // simpan permanen hanya lewat tombol "Simpan".
        await ApiConfig.instance.setBaseUrl(previous);
      }
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiConfig.instance.setBaseUrl(_controller.text);
    } on FormatException catch (e) {
      if (mounted) {
        setState(() {
          _testOk = false;
          _testResult = e.message;
          _saving = false;
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onSaved?.call();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Server')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'GeoTani membutuhkan koneksi ke server lokal (laptop di jaringan '
            'WiFi yang sama) agar data bisa disinkronkan antar HP. Masukkan '
            'alamat IP laptop server, contoh: 192.168.1.2:3000',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Alamat server',
              hintText: 'http://192.168.1.2:3000',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _testing ? null : _testConnection,
            icon: _testing
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.wifi_tethering),
            label: const Text('Test Connection'),
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 8),
            Text(
              _testResult!,
              style: TextStyle(color: _testOk ? Colors.green[700] : Colors.red),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
