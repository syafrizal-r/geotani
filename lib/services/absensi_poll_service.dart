import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/absensi.dart';
import '../data/repositories/absensi_repository.dart';
import '../data/repositories/spt_repository.dart';
import 'notification_service.dart';

/// Polling ringan (tanpa push/FCM) yang mendeteksi perubahan status
/// absensi/approval yang terjadi di device lain lewat REST API, lalu memicu
/// notifikasi lokal di device ini. Best-effort: hanya berjalan saat layar
/// terkait sedang aktif di foreground, interval ~15 detik -- konsekuensi
/// yang disengaja dari keputusan "tanpa infrastruktur push/cloud".
///
/// Status approval terakhir yang sudah "dilihat" PPL disimpan di
/// SharedPreferences, jadi persetujuan yang terjadi saat aplikasi ditutup
/// tetap memicu notifikasi begitu aplikasi dibuka/kembali ke foreground.
class AbsensiPollService {
  final AbsensiRepository _absensiRepository;
  final SptRepository _sptRepository;
  Timer? _timer;
  AppLifecycleListener? _lifecycle;

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
    _listenResume(() => _pollForPpl(pegawaiId));
    _pollForPpl(pegawaiId);
  }

  /// Dipanggil dari dashboard Koordinator: notifikasi lokal saat jumlah
  /// absensi yang menunggu persetujuan bertambah.
  void startForKoordinator({Duration interval = const Duration(seconds: 15)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _pollForKoordinator());
    _listenResume(_pollForKoordinator);
    _pollForKoordinator();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _lifecycle?.dispose();
    _lifecycle = null;
  }

  /// Timer.periodic membeku saat aplikasi di background; poll sekali begitu
  /// aplikasi kembali ke foreground supaya tidak menunggu tick berikutnya.
  void _listenResume(VoidCallback poll) {
    _lifecycle?.dispose();
    _lifecycle = AppLifecycleListener(onResume: poll);
  }

  static String _seenKey(int pegawaiId) => 'approval_seen_$pegawaiId';

  Future<Map<int, ApprovalStatus>?> _loadSeen(int pegawaiId) async {
    final raw = (await SharedPreferences.getInstance()).getString(_seenKey(pegawaiId));
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in map.entries) int.parse(e.key): ApprovalStatusX.fromDb(e.value as String),
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveSeen(int pegawaiId, Map<int, ApprovalStatus> seen) async {
    final raw = jsonEncode({for (final e in seen.entries) '${e.key}': e.value.dbValue});
    await (await SharedPreferences.getInstance()).setString(_seenKey(pegawaiId), raw);
  }

  Future<void> _pollForPpl(int pegawaiId) async {
    try {
      final list = await _absensiRepository.findByPegawai(pegawaiId);
      final previous = _lastApprovalByAbsensiId ?? await _loadSeen(pegawaiId);
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
      await _saveSeen(pegawaiId, current);
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
