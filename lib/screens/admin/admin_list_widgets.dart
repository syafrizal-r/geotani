import 'package:flutter/material.dart';

/// Kotak pencarian di atas daftar data pada tab-tab Admin.
class AdminSearchField extends StatelessWidget {
  final String hintText;
  final ValueChanged<String> onChanged;

  const AdminSearchField({super.key, required this.hintText, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search),
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

/// Pesan kosong/gagal yang tetap bisa ditarik untuk refresh (dibungkus
/// ListView supaya RefreshIndicator di atasnya tetap berfungsi).
class AdminListMessage extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AdminListMessage(this.message, {super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Text(message, textAlign: TextAlign.center),
              if (onRetry != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba lagi'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
