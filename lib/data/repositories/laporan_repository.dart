import 'dart:io';

import '../../services/api_client.dart';
import '../models/laporan.dart';

class LaporanRepository {
  /// [newFotoFile] adalah file lokal yang diunggah sebagai multipart. Beda
  /// dari [laporan.fotoPath] yang (pada objek hasil server) berisi URL, bukan
  /// path lokal -- lihat LaporanFormScreen untuk bagaimana keduanya dipisah.
  Future<int> insert(Laporan laporan, {File? newFotoFile}) async {
    final fields = <String, String>{
      'spt_id': '${laporan.sptId}',
      'pegawai_id': '${laporan.pegawaiId}',
      'catatan': laporan.catatan,
      'waktu_dibuat': laporan.waktuDibuat.toIso8601String(),
    };
    final row = await ApiClient.instance.multipart('POST', '/api/laporan', fields: fields, file: newFotoFile);
    return (row as Map)['id'] as int;
  }

  /// [newFotoFile] null berarti tidak ada foto baru dipilih -- server
  /// mempertahankan foto lama, bukan menghapusnya.
  Future<void> update(Laporan laporan, {File? newFotoFile}) async {
    final fields = <String, String>{
      'catatan': laporan.catatan,
      'waktu_dibuat': laporan.waktuDibuat.toIso8601String(),
    };
    await ApiClient.instance.multipart('PUT', '/api/laporan/${laporan.id}', fields: fields, file: newFotoFile);
  }

  Future<Laporan?> findBySpt(int sptId) async {
    final row = await ApiClient.instance.get('/api/laporan', query: {'sptId': '$sptId'});
    if (row == null) return null;
    return Laporan.fromMap(row as Map<String, dynamic>);
  }
}
