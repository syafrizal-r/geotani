class Laporan {
  final int? id;
  final int sptId;
  final int pegawaiId;
  final String catatan;
  final String? fotoPath;
  final DateTime waktuDibuat;

  const Laporan({
    this.id,
    required this.sptId,
    required this.pegawaiId,
    required this.catatan,
    this.fotoPath,
    required this.waktuDibuat,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'spt_id': sptId,
      'pegawai_id': pegawaiId,
      'catatan': catatan,
      'foto_path': fotoPath,
      'waktu_dibuat': waktuDibuat.toIso8601String(),
    };
  }

  factory Laporan.fromMap(Map<String, Object?> map) {
    return Laporan(
      id: map['id'] as int?,
      sptId: map['spt_id'] as int,
      pegawaiId: map['pegawai_id'] as int,
      catatan: map['catatan'] as String,
      fotoPath: map['foto_path'] as String?,
      waktuDibuat: DateTime.parse(map['waktu_dibuat'] as String),
    );
  }
}
