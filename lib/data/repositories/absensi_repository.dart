import 'dart:io';

import '../../services/api_client.dart';
import '../models/absensi.dart';

class AbsensiRepository {
  /// [absensi.fotoPath], jika ada, diperlakukan sebagai path file lokal di
  /// device ini dan diunggah sebagai multipart. Objek yang dikembalikan
  /// membawa foto_path hasil server (URL relatif), bukan path lokal --
  /// karena itu method ini mengembalikan Absensi penuh, bukan cuma id.
  Future<Absensi> insert(Absensi absensi) async {
    final fields = <String, String>{
      'spt_id': '${absensi.sptId}',
      'pegawai_id': '${absensi.pegawaiId}',
      'tipe': absensi.tipe.dbValue,
      'waktu': absensi.waktu.toIso8601String(),
      'latitude': '${absensi.latitude}',
      'longitude': '${absensi.longitude}',
      'jarak_meter': '${absensi.jarakMeter}',
      'face_similarity': '${absensi.faceSimilarity}',
      'status': absensi.status.dbValue,
    };
    final hasLocalFoto = absensi.fotoPath != null && absensi.fotoPath!.isNotEmpty;
    final row = await ApiClient.instance.multipart(
      'POST',
      '/api/absensi',
      fields: fields,
      file: hasLocalFoto ? File(absensi.fotoPath!) : null,
    );
    return Absensi.fromMap(row as Map<String, dynamic>);
  }

  Future<List<Absensi>> findBySpt(int sptId) async {
    final rows = await ApiClient.instance.get('/api/absensi', query: {'sptId': '$sptId'}) as List;
    return rows.map((r) => Absensi.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<bool> hasValidAbsensi(int sptId, TipeAbsensi tipe) async {
    final result = await ApiClient.instance.get(
      '/api/absensi/has-valid',
      query: {'sptId': '$sptId', 'tipe': tipe.dbValue},
    );
    return (result as Map)['hasValid'] as bool;
  }

  Future<List<Absensi>> findByPegawai(int pegawaiId) async {
    final rows = await ApiClient.instance.get('/api/absensi', query: {'pegawaiId': '$pegawaiId'}) as List;
    return rows.map((r) => Absensi.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Absensi yang sudah tervalidasi otomatis (GPS + wajah) tapi belum
  /// ditinjau/disetujui oleh atasan.
  Future<List<Absensi>> findPendingApproval() async {
    final rows = await ApiClient.instance.get('/api/absensi', query: {'pendingApproval': 'true'}) as List;
    return rows.map((r) => Absensi.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Seluruh riwayat absensi untuk kebutuhan rekap, terbaru lebih dulu.
  Future<List<Absensi>> findAll() async {
    final rows = await ApiClient.instance.get('/api/absensi') as List;
    return rows.map((r) => Absensi.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> setApproval({
    required int absensiId,
    required ApprovalStatus status,
    required int approvedById,
    String? catatan,
  }) async {
    // approvedById tidak dikirim: server mengambilnya dari token JWT
    // (koordinator yang sedang login), bukan dari client, demi keamanan.
    await ApiClient.instance.patch(
      '/api/absensi/$absensiId/approval',
      body: {'status': status.dbValue, 'catatan': catatan},
    );
  }
}
