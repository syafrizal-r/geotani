enum SptStatus { menunggu, berlangsung, selesai, ditolak }

extension SptStatusX on SptStatus {
  String get dbValue => switch (this) {
        SptStatus.menunggu => 'menunggu',
        SptStatus.berlangsung => 'berlangsung',
        SptStatus.selesai => 'selesai',
        SptStatus.ditolak => 'ditolak',
      };

  String get label => switch (this) {
        SptStatus.menunggu => 'Menunggu Pelaksanaan',
        SptStatus.berlangsung => 'Sedang Berlangsung',
        SptStatus.selesai => 'Selesai',
        SptStatus.ditolak => 'Ditolak',
      };

  static SptStatus fromDb(String value) {
    return SptStatus.values.firstWhere((s) => s.dbValue == value);
  }
}

class Spt {
  final int? id;
  final String nomorSpt;
  final int pegawaiId;
  final int lokasiId;
  final String agenda;
  final DateTime tanggalMulai;
  final DateTime tanggalSelesai;
  final SptStatus status;

  const Spt({
    this.id,
    required this.nomorSpt,
    required this.pegawaiId,
    required this.lokasiId,
    required this.agenda,
    required this.tanggalMulai,
    required this.tanggalSelesai,
    required this.status,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'nomor_spt': nomorSpt,
      'pegawai_id': pegawaiId,
      'lokasi_id': lokasiId,
      'agenda': agenda,
      'tanggal_mulai': tanggalMulai.toIso8601String(),
      'tanggal_selesai': tanggalSelesai.toIso8601String(),
      'status': status.dbValue,
    };
  }

  factory Spt.fromMap(Map<String, Object?> map) {
    return Spt(
      id: map['id'] as int?,
      nomorSpt: map['nomor_spt'] as String,
      pegawaiId: map['pegawai_id'] as int,
      lokasiId: map['lokasi_id'] as int,
      agenda: map['agenda'] as String,
      tanggalMulai: DateTime.parse(map['tanggal_mulai'] as String),
      tanggalSelesai: DateTime.parse(map['tanggal_selesai'] as String),
      status: SptStatusX.fromDb(map['status'] as String),
    );
  }
}
