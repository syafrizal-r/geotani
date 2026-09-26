# Model Face Recognition (belum disertakan)

Folder ini harus berisi file **`mobilefacenet.tflite`** — model wajib diunduh manual
karena berupa file biner (bobot model ML), tidak bisa dibuat lewat kode.

## Yang dibutuhkan
- Nama file: `mobilefacenet.tflite`
- Input: gambar wajah 112x112 RGB (nilai piksel dinormalisasi ke [-1, 1] atau [0, 1] sesuai model)
- Output: vector embedding 192-d atau 128-d (float32)
- Ukuran umum: 4-6 MB

## Cara mendapatkan
1. Cari model open-source "MobileFaceNet TFLite" atau "FaceNet TFLite" di GitHub/Kaggle
   (banyak repo publik yang menyediakan hasil konversi TFLite dari model MobileFaceNet/FaceNet
   yang sudah dilatih di dataset publik seperti CASIA-WebFace/MS-Celeb-1M).
2. Pastikan lisensinya mengizinkan penggunaan untuk tugas/riset.
3. Simpan file hasil unduhan sebagai `assets/models/mobilefacenet.tflite`.
4. Jika ukuran input model berbeda dari 112x112 atau nama output layer berbeda,
   sesuaikan konstanta di `lib/core/constants.dart` dan `lib/services/face_recognition_service.dart`.

Selama file ini belum ada, aplikasi tetap bisa dijalankan (login, lihat SPT, validasi GPS)
tapi tahap **validasi wajah** akan menampilkan pesan error yang jelas alih-alih crash,
lihat `FaceRecognitionService._ensureModelLoaded()`.
