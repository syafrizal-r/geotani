import 'package:geolocator/geolocator.dart';

class LocationValidationResult {
  final Position position;
  final double jarakMeter;
  final bool dalamRadius;

  const LocationValidationResult({
    required this.position,
    required this.jarakMeter,
    required this.dalamRadius,
  });
}

class LocationPermissionException implements Exception {
  final String message;
  const LocationPermissionException(this.message);

  @override
  String toString() => message;
}

class LocationService {
  Future<Position> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationPermissionException(
        'Layanan lokasi (GPS) tidak aktif. Aktifkan GPS terlebih dahulu.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationPermissionException(
          'Izin akses lokasi ditolak. Aplikasi memerlukan akses lokasi untuk absen.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationPermissionException(
        'Izin lokasi ditolak permanen. Aktifkan izin lokasi lewat pengaturan aplikasi.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  /// Menghitung jarak (meter) posisi saat ini terhadap titik lokasi tugas,
  /// lalu menentukan apakah berada dalam radius toleransi.
  Future<LocationValidationResult> validateAgainst({
    required double targetLatitude,
    required double targetLongitude,
    required double radiusMeter,
  }) async {
    final position = await getCurrentPosition();
    final jarak = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      targetLatitude,
      targetLongitude,
    );

    return LocationValidationResult(
      position: position,
      jarakMeter: jarak,
      dalamRadius: jarak <= radiusMeter,
    );
  }
}
