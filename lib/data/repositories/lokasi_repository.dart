import '../../services/api_client.dart';
import '../models/lokasi.dart';

class LokasiRepository {
  Future<List<Lokasi>> findAll() async {
    final rows = await ApiClient.instance.get('/api/lokasi') as List;
    return rows.map((r) => Lokasi.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<Lokasi?> findById(int id) async {
    try {
      final row = await ApiClient.instance.get('/api/lokasi/$id');
      return Lokasi.fromMap(row as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<int> insert(Lokasi lokasi) async {
    final row = await ApiClient.instance.post('/api/lokasi', body: lokasi.toMap()..remove('id'));
    return row['id'] as int;
  }

  Future<void> update(Lokasi lokasi) async {
    await ApiClient.instance.put('/api/lokasi/${lokasi.id}', body: lokasi.toMap()..remove('id'));
  }

  Future<void> delete(int id) async {
    await ApiClient.instance.delete('/api/lokasi/$id');
  }
}
