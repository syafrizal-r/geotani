import 'package:flutter/material.dart';

import '../core/api_config.dart';

/// Menampilkan foto yang tersimpan di server (path relatif seperti
/// "/uploads/absensi/x.jpg") lewat Image.network, dengan state loading dan
/// placeholder error -- pengganti Image.file(File(fotoPath)) lama yang
/// mengasumsikan foto ada di penyimpanan device ini.
class NetworkOrPlaceholderImage extends StatelessWidget {
  final String? path;
  final double? height;
  final BoxFit fit;

  const NetworkOrPlaceholderImage({
    super.key,
    required this.path,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final url = ApiConfig.instance.resolveMediaUrl(path);
    if (url == null) {
      return _placeholder(context, icon: Icons.image_not_supported_outlined, text: 'Tidak ada foto');
    }
    return Image.network(
      url,
      headers: ApiConfig.commonHeaders,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return SizedBox(
          height: height,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return _placeholder(context, icon: Icons.broken_image_outlined, text: 'Gagal memuat foto');
      },
    );
  }

  Widget _placeholder(BuildContext context, {required IconData icon, required String text}) {
    return Container(
      height: height ?? 160,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.black38),
            const SizedBox(height: 4),
            Text(text, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}
