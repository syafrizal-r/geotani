# GeoTani

Aplikasi e-absensi (Flutter) untuk Penyuluh Pertanian Lapangan (PPL) — studi kasus
Dinas Pertanian Provinsi Sumatera Utara. Absensi diverifikasi dengan **GPS geofencing**
terhadap lokasi pada Surat Perintah Tugas (SPT) dan **face recognition on-device**
(TFLite / MobileFaceNet).

Peran: Admin Kepegawaian, Koordinator Penyuluh, PPL, Kepala Dinas.

## Struktur

- `lib/` — aplikasi Flutter
- `server/` — REST API (Node.js/Express + SQLite), lihat [server/README.md](server/README.md)

## Menjalankan

```
# server
cd server
npm install
cp .env.example .env   # isi JWT_SECRET
npm run seed
npm start

# aplikasi
flutter pub get
flutter run
```

Alamat server dapat diubah dari layar **Pengaturan Server** di aplikasi.
