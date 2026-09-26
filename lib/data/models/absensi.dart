enum TipeAbsensi { checkIn, checkOut }

extension TipeAbsensiX on TipeAbsensi {
  String get dbValue => this == TipeAbsensi.checkIn ? 'check_in' : 'check_out';
  String get label => this == TipeAbsensi.checkIn ? 'Check-in' : 'Check-out';

  static TipeAbsensi fromDb(String value) {
    return value == 'check_in' ? TipeAbsensi.checkIn : TipeAbsensi.checkOut;
  }
}

enum StatusAbsensi { tervalidasi, ditolakLokasi, ditolakWajah }

extension StatusAbsensiX on StatusAbsensi {
  String get dbValue => switch (this) {
        StatusAbsensi.tervalidasi => 'tervalidasi',
        StatusAbsensi.ditolakLokasi => 'ditolak_lokasi',
        StatusAbsensi.ditolakWajah => 'ditolak_wajah',
      };

  String get label => switch (this) {
        StatusAbsensi.tervalidasi => 'Tervalidasi',
        StatusAbsensi.ditolakLokasi => 'Ditolak (Di luar lokasi)',
        StatusAbsensi.ditolakWajah => 'Ditolak (Wajah tidak cocok)',
      };

  static StatusAbsensi fromDb(String value) {
    return StatusAbsensi.values.firstWhere((s) => s.dbValue == value);
  }
}

/// Status persetujuan administratif oleh Koordinator Penyuluh, terpisah dari
/// [StatusAbsensi] yang merupakan hasil validasi otomatis GPS + wajah.
enum ApprovalStatus { menunggu, disetujui, ditolak }

extension ApprovalStatusX on ApprovalStatus {
  String get dbValue => switch (this) {
        ApprovalStatus.menunggu => 'menunggu',
        ApprovalStatus.disetujui => 'disetujui',
        ApprovalStatus.ditolak => 'ditolak',
      };

  String get label => switch (this) {
        ApprovalStatus.menunggu => 'Menunggu Persetujuan',
        ApprovalStatus.disetujui => 'Disetujui',
        ApprovalStatus.ditolak => 'Ditolak',
      };

  static ApprovalStatus fromDb(String value) {
    return ApprovalStatus.values.firstWhere((s) => s.dbValue == value);
  }
}

class Absensi {
  final int? id;
  final int sptId;
  final int pegawaiId;
  final TipeAbsensi tipe;
  final DateTime waktu;
  final double latitude;
  final double longitude;
  final double jarakMeter;
  final double faceSimilarity;
  final StatusAbsensi status;
  final String? fotoPath;
  final ApprovalStatus approvalStatus;
  final String? approvalCatatan;
  final int? approvalOlehId;
  final DateTime? approvalWaktu;

  const Absensi({
    this.id,
    required this.sptId,
    required this.pegawaiId,
    required this.tipe,
    required this.waktu,
    required this.latitude,
    required this.longitude,
    required this.jarakMeter,
    required this.faceSimilarity,
    required this.status,
    this.fotoPath,
    this.approvalStatus = ApprovalStatus.menunggu,
    this.approvalCatatan,
    this.approvalOlehId,
    this.approvalWaktu,
  });

  /// Hanya absensi yang tervalidasi otomatis yang relevan untuk ditinjau atasan.
  bool get perluDitinjau =>
      status == StatusAbsensi.tervalidasi && approvalStatus == ApprovalStatus.menunggu;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'spt_id': sptId,
      'pegawai_id': pegawaiId,
      'tipe': tipe.dbValue,
      'waktu': waktu.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'jarak_meter': jarakMeter,
      'face_similarity': faceSimilarity,
      'status': status.dbValue,
      'foto_path': fotoPath,
      'approval_status': approvalStatus.dbValue,
      'approval_catatan': approvalCatatan,
      'approval_oleh_id': approvalOlehId,
      'approval_waktu': approvalWaktu?.toIso8601String(),
    };
  }

  factory Absensi.fromMap(Map<String, Object?> map) {
    return Absensi(
      id: map['id'] as int?,
      sptId: map['spt_id'] as int,
      pegawaiId: map['pegawai_id'] as int,
      tipe: TipeAbsensiX.fromDb(map['tipe'] as String),
      waktu: DateTime.parse(map['waktu'] as String),
      // (num).toDouble(): lewat JSON, nilai bulat tiba sebagai int, bukan
      // double -- beda dari sqflite yang selalu mengembalikan REAL sebagai double.
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      jarakMeter: (map['jarak_meter'] as num).toDouble(),
      faceSimilarity: (map['face_similarity'] as num).toDouble(),
      status: StatusAbsensiX.fromDb(map['status'] as String),
      fotoPath: map['foto_path'] as String?,
      approvalStatus: ApprovalStatusX.fromDb(map['approval_status'] as String? ?? 'menunggu'),
      approvalCatatan: map['approval_catatan'] as String?,
      approvalOlehId: map['approval_oleh_id'] as int?,
      approvalWaktu:
          map['approval_waktu'] != null ? DateTime.parse(map['approval_waktu'] as String) : null,
    );
  }
}
