enum PegawaiRole { admin, koordinator, ppl, kepalaDinas }

extension PegawaiRoleX on PegawaiRole {
  String get dbValue => switch (this) {
        PegawaiRole.admin => 'admin',
        PegawaiRole.koordinator => 'koordinator',
        PegawaiRole.ppl => 'ppl',
        PegawaiRole.kepalaDinas => 'kepala_dinas',
      };

  String get label => switch (this) {
        PegawaiRole.admin => 'Admin Kepegawaian',
        PegawaiRole.koordinator => 'Koordinator Penyuluh',
        PegawaiRole.ppl => 'Penyuluh Pertanian Lapangan',
        PegawaiRole.kepalaDinas => 'Kepala Dinas',
      };

  static PegawaiRole fromDb(String value) {
    return PegawaiRole.values.firstWhere((r) => r.dbValue == value);
  }
}

class Pegawai {
  final int? id;
  final String nip;
  final String nama;
  final String username;

  /// Null saat data berasal dari server (yang tidak pernah mengirim hash
  /// lewat jaringan demi keamanan) -- lihat PegawaiRepository.insert/update
  /// untuk bagaimana null di sini ditangani sebagai "jangan ubah password".
  final String? passwordHash;
  final PegawaiRole role;

  /// Embedding wajah referensi hasil enrolment, disimpan sebagai string
  /// angka float dipisah koma. Null jika pegawai belum melakukan enrolment wajah.
  final String? faceEmbedding;

  const Pegawai({
    this.id,
    required this.nip,
    required this.nama,
    required this.username,
    required this.passwordHash,
    required this.role,
    this.faceEmbedding,
  });

  bool get isEnrolled => faceEmbedding != null && faceEmbedding!.isNotEmpty;

  List<double> get embeddingVector {
    if (!isEnrolled) return const [];
    return faceEmbedding!.split(',').map(double.parse).toList();
  }

  Pegawai copyWith({String? faceEmbedding}) {
    return Pegawai(
      id: id,
      nip: nip,
      nama: nama,
      username: username,
      passwordHash: passwordHash,
      role: role,
      faceEmbedding: faceEmbedding ?? this.faceEmbedding,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'nip': nip,
      'nama': nama,
      'username': username,
      'password_hash': passwordHash,
      'role': role.dbValue,
      'face_embedding': faceEmbedding,
    };
  }

  factory Pegawai.fromMap(Map<String, Object?> map) {
    return Pegawai(
      id: map['id'] as int?,
      nip: map['nip'] as String,
      nama: map['nama'] as String,
      username: map['username'] as String,
      passwordHash: map['password_hash'] as String?,
      role: PegawaiRoleX.fromDb(map['role'] as String),
      faceEmbedding: map['face_embedding'] as String?,
    );
  }
}
