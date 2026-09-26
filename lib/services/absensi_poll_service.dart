import 'dart:async';

import '../data/models/absensi.dart';
import '../data/repositories/absensi_repository.dart';
import '../data/repositories/spt_repository.dart';
import 'notification_service.dart';

/// Polling ringan (tanpa push/FCM) yang mendeteksi perubahan status
/// absensi/approval yang terjadi di device lain lewat REST API, lalu memicu
/// notifikasi lokal di device ini. Best-effort: hanya berjalan saat layar
/// terkait sedang aktif di foreground, interval ~15 detik -- konsekuensi
/// yang disengaja dari keputusan "tanpa infrastruktur push/cloud".
class AbsensiPollService {
  final AbsensiRepository _absensiRepository;
  final SptRepository _sptRepository;
  Timer? _timer;

  AbsensiPollService({AbsensiRepository? absensiRepository, SptRepository? sptRepository})
      : _absensiRepository = absensiRepository ?? AbsensiRepository(),
        _sptRepository = sptRepository ?? SptRepository();

  Map<int, ApprovalStatus>? _lastApprovalByAbsensiId;
  int? _lastPendingCount;

  /// Dipanggil dari dashboard PPL: notifikasi lokal saat approval_status
  /// salah satu absensi milik pegawai ini berubah dari 'menunggu' ke status lain.
  void startForPpl(int pegawaiId, {Duration interval = const Duration(seconds: 15)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _pollForPpl(pegawaiId));
    _pollForPpl(pegawaiId);
  }

  /// Dipanggil dari dashboard Koordinator: notifikasi lokal saat jumlah
  /// absensi yang menunggu persetujuan bertambah.
  void startForKoordinator({Duration interval = const Duration(seconds: 15)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _pollForKoordinator());
    _pollForKoordinator();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _pollForPpl(int pegawaiId) async {
    try {
      final list = await _absensiRepository.findByPegawai(pegawaiId);
      final previous = _lastApprovalByAbsensiId;
      final current = {for (final a in list) a.id!: a.approvalStatus};

      if (previous != null) {
        for (final absensi in list) {
          final before = previous[absensi.id];
          final after = absensi.approvalStatus;
          if (before == ApprovalStatus.menunggu && after != ApprovalStatus.menunggu) {
            final spt = await _sptRepository.findById(absensi.sptId);
            await NotificationService.instance.showApprovalResult(
              absensiId: absensi.id!,
              sptAgenda: spt?.agenda ?? 'SPT #${absensi.sptId}',
              status: after,
              catatan: absensi.approvalCatatan,
            );
          }
        }
      }
      _lastApprovalByAbsensiId = current;
    } catch (_) {
      // Best-effort: server sempat tidak terjangkau -> coba lagi interval berikutnya.
    }
  }

  Future<void> _pollForKoordinator() async {
    try {
      final list = await _absensiRepository.findPendingApproval();
      final count = list.length;
      if (_lastPendingCount != null && count > _lastPendingCount!) {
        await NotificationService.instance.showPendingApprovalCount(count);
      }
      _lastPendingCount = count;
    } catch (_) {
      // idem
    }
  }
}
