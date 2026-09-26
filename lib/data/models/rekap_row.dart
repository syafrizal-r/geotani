import 'absensi.dart';
import 'pegawai.dart';
import 'spt.dart';

/// Satu baris rekap absensi gabungan, dipakai bersama oleh layar rekap dan
/// layanan export (PDF/Excel).
class RekapRow {
  final Absensi absensi;
  final Pegawai pegawai;
  final Spt spt;

  const RekapRow({required this.absensi, required this.pegawai, required this.spt});
}
