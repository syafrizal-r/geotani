import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/models/absensi.dart';

/// Notifikasi lokal (tanpa server push/FCM -- server GeoTani hanya REST API
/// biasa) dipicu dari dalam app: baik langsung setelah aksi sendiri, maupun
/// (untuk event dari device lain) lewat AbsensiPollService.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  /// Hijau GeoTani untuk ikon kecil & aksen notifikasi (tanpa ini Android
  /// menampilkan siluet ic_stat_geotani dalam abu-abu).
  static const _brandColor = Color(0xFF2E7D32);

  /// Ikon GeoTani berwarna di sisi kanan notifikasi. Beberapa launcher
  /// (mis. Samsung One UI) mengabaikan [_brandColor] dan tetap menggambar
  /// ikon kecil abu-abu, jadi ini yang menjamin notifikasi tetap berwarna.
  static const _largeIcon = DrawableResourceAndroidBitmap('ic_notif_large');

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings('ic_stat_geotani');
    await _plugin.initialize(settings: const InitializationSettings(android: androidSettings));
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _initialized = true;
  }

  Future<void> showApprovalResult({
    required int absensiId,
    required String sptAgenda,
    required ApprovalStatus status,
    String? catatan,
  }) async {
    final disetujui = status == ApprovalStatus.disetujui;
    final title = disetujui ? 'Absensi Disetujui' : 'Absensi Ditolak';
    final body = StringBuffer(
      disetujui
          ? 'Absensi Anda untuk "$sptAgenda" telah disetujui Koordinator.'
          : 'Absensi Anda untuk "$sptAgenda" ditolak Koordinator.',
    );
    if (catatan != null && catatan.isNotEmpty) {
      body.write(' Catatan: $catatan');
    }
    final bodyText = body.toString();
    final androidDetails = AndroidNotificationDetails(
      'approval_channel',
      'Persetujuan Absensi',
      channelDescription: 'Notifikasi hasil persetujuan absensi oleh Koordinator',
      importance: Importance.high,
      priority: Priority.high,
      color: _brandColor,
      largeIcon: _largeIcon,
      styleInformation: BigTextStyleInformation(bodyText),
    );
    await _plugin.show(
      id: absensiId,
      title: title,
      body: bodyText,
      notificationDetails: NotificationDetails(android: androidDetails),
    );
  }

  /// Notifikasi ringan untuk Koordinator saat AbsensiPollService mendeteksi
  /// pertambahan jumlah absensi yang menunggu persetujuan (dari PPL lain di
  /// device berbeda). id notifikasi tetap sama supaya menggantikan
  /// (bukan menumpuk) notifikasi sebelumnya.
  Future<void> showPendingApprovalCount(int count) async {
    const androidDetails = AndroidNotificationDetails(
      'pending_approval_channel',
      'Absensi Menunggu Persetujuan',
      channelDescription: 'Notifikasi saat ada absensi baru yang menunggu persetujuan Koordinator',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      color: _brandColor,
      largeIcon: _largeIcon,
    );
    await _plugin.show(
      id: -1,
      title: 'Absensi Menunggu Persetujuan',
      body: '$count absensi menunggu persetujuan Anda.',
      notificationDetails: const NotificationDetails(android: androidDetails),
    );
  }
}
