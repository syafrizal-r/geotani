import '../../services/api_client.dart';
import '../models/pegawai.dart';

class PegawaiRepository {
  // findByUsername dropped: login now happens server-side
  // (AuthService -> POST /api/auth/login), it was its only caller.

  Future<List<Pegawai>> findAll() async {
    final rows = await ApiClient.instance.get('/api/pegawai') as List;
    return rows.map((r) => Pegawai.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<Pegawai?> findById(int id) async {
    try {
      final row = await ApiClient.instance.get('/api/pegawai/$id');
      return Pegawai.fromMap(row as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> saveFaceEmbedding(int pegawaiId, List<double> embedding) async {
    await ApiClient.instance.put(
      '/api/pegawai/$pegawaiId/face-embedding',
      body: {'embedding': embedding},
    );
  }

  Future<int> insert(Pegawai pegawai) async {
    final row = await ApiClient.instance.post('/api/pegawai', body: pegawai.toMap()..remove('id'));
    return row['id'] as int;
  }

  Future<void> update(Pegawai pegawai) async {
    await ApiClient.instance.put('/api/pegawai/${pegawai.id}', body: pegawai.toMap()..remove('id'));
  }

  Future<void> delete(int id) async {
    await ApiClient.instance.delete('/api/pegawai/$id');
  }
}
