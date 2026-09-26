import '../../services/api_client.dart';
import '../models/spt.dart';

class SptRepository {
  Future<List<Spt>> findByPegawai(int pegawaiId) async {
    final rows = await ApiClient.instance.get('/api/spt', query: {'pegawaiId': '$pegawaiId'}) as List;
    return rows.map((r) => Spt.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<List<Spt>> findAll() async {
    final rows = await ApiClient.instance.get('/api/spt') as List;
    return rows.map((r) => Spt.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<Spt?> findById(int id) async {
    try {
      final row = await ApiClient.instance.get('/api/spt/$id');
      return Spt.fromMap(row as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> updateStatus(int sptId, SptStatus status) async {
    await ApiClient.instance.patch('/api/spt/$sptId/status', body: {'status': status.dbValue});
  }

  /// Mirip existsForLokasi lama: cek lewat filter ?lokasiId= alih-alih
  /// endpoint khusus, dipakai sebagai delete-guard sebelum hapus Lokasi.
  Future<bool> existsForLokasi(int lokasiId) async {
    final rows = await ApiClient.instance.get('/api/spt', query: {'lokasiId': '$lokasiId'}) as List;
    return rows.isNotEmpty;
  }

  Future<int> insert(Spt spt) async {
    final row = await ApiClient.instance.post('/api/spt', body: spt.toMap()..remove('id'));
    return row['id'] as int;
  }

  Future<void> update(Spt spt) async {
    await ApiClient.instance.put('/api/spt/${spt.id}', body: spt.toMap()..remove('id'));
  }

  Future<void> delete(int id) async {
    await ApiClient.instance.delete('/api/spt/$id');
  }
}
