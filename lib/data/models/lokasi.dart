class Lokasi {
  final int? id;
  final String nama;
  final String alamat;
  final double latitude;
  final double longitude;
  final double radiusMeter;

  const Lokasi({
    this.id,
    required this.nama,
    required this.alamat,
    required this.latitude,
    required this.longitude,
    required this.radiusMeter,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'nama': nama,
      'alamat': alamat,
      'latitude': latitude,
      'longitude': longitude,
      'radius_meter': radiusMeter,
    };
  }

  factory Lokasi.fromMap(Map<String, Object?> map) {
    return Lokasi(
      id: map['id'] as int?,
      nama: map['nama'] as String,
      alamat: map['alamat'] as String,
      // (num).toDouble(): lewat JSON, nilai bulat seperti radius 100 tiba
      // sebagai int, bukan double -- beda dari sqflite yang selalu
      // mengembalikan REAL sebagai double.
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      radiusMeter: (map['radius_meter'] as num).toDouble(),
    );
  }
}
