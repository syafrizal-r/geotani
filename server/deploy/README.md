# Deploy GeoTani ke VPS

Memindahkan server dari laptop (+ ngrok) ke VPS berbayar, supaya aplikasi
tetap jalan walaupun laptop mati. Alamat akhirnya `https://<domain-anda>`.

## 1. Beli VPS

Provider lokal (IDCloudHost, Biznet Gio, Hostinger, Jagoan Hosting, dsb.) —
spesifikasi paling kecil sudah cukup:

| | Minimal |
|---|---|
| OS | **Ubuntu 24.04** (atau 22.04) |
| CPU / RAM | 1 vCPU / 1 GB |
| Disk | 20 GB (foto absensi ± 1–3 MB per check-in) |
| Lokasi | Jakarta / Indonesia |

Catat **IP publik** dan **password root** yang dikirim provider.

## 2. Beli domain dan arahkan ke VPS

Beli domain (mis. `geotani.my.id`), lalu di panel DNS-nya buat record:

| Tipe | Nama | Nilai |
|---|---|---|
| A | `@` | IP VPS |

Tunggu beberapa menit, cek di PowerShell: `nslookup geotani.my.id` harus
menampilkan IP VPS. **Langkah 4 butuh ini sudah benar**, karena sertifikat
HTTPS hanya bisa dibuat kalau domain sudah mengarah ke VPS.

## 3. Push kode terbaru ke GitHub

VPS mengambil kode dari https://github.com/syafrizal-r/geotani, jadi pastikan
perubahan terbaru sudah di-push (`git push`).

## 4. Setup VPS (sekali saja)

Dari PowerShell di laptop:

```
ssh root@<IP-VPS>
```

Lalu di dalam VPS:

```
curl -fsSL https://raw.githubusercontent.com/syafrizal-r/geotani/main/server/deploy/setup-vps.sh -o setup-vps.sh
bash setup-vps.sh geotani.my.id
```

Script ini memasang Node.js, Caddy (HTTPS otomatis), service `geotani` yang
otomatis nyala setelah reboot, firewall, dan backup database harian. Setelah
selesai, `https://geotani.my.id` sudah menampilkan halaman status (databasenya
masih kosong). Ketik `exit` untuk keluar dari VPS.

## 5. Pindahkan data dari laptop

Di PowerShell laptop, dari folder `server`:

```
powershell -ExecutionPolicy Bypass -File deploy\export-data.ps1 <IP-VPS>
```

Script ini mengirim database, foto absensi/laporan, dan file APK ke VPS, lalu
memasangnya. Password root akan ditanya 2 kali. Data laptop tidak berubah.

> Kalau mau mulai dari data contoh saja (tanpa data laptop), di VPS jalankan:
> `cd /opt/geotani/server && sudo -u geotani npm run seed`

## 6. Arahkan aplikasi ke server baru

Ubah `_defaultBaseUrl` di `lib/core/api_config.dart` ke `https://geotani.my.id`,
build ulang APK, lalu upload lagi (`server/downloads/` di VPS lewat langkah 5
atau `scp`, dan GitHub Release). HP yang sudah terpasang bisa langsung pakai
tanpa install ulang: **Pengaturan Server** di layar login → isi alamat baru.

Setelah itu ngrok dan server di laptop tidak dibutuhkan lagi.

## Perintah sehari-hari (di VPS)

| Keperluan | Perintah |
|---|---|
| Update ke kode terbaru di GitHub | `bash /opt/geotani/server/deploy/update.sh` |
| Lihat status server | `systemctl status geotani` |
| Lihat log | `journalctl -u geotani -n 100 -f` |
| Restart | `systemctl restart geotani` |
| Daftar backup | `ls /var/backups/geotani` |
| Upload APK baru dari laptop | `scp build\app\outputs\flutter-apk\app-release.apk root@<IP>:/opt/geotani/server/downloads/GeoTani.apk` |

Database ada di `/opt/geotani/server/data/geotani.db`, foto di
`/opt/geotani/server/uploads/`. Backup harian hanya mencakup database; foto
sebaiknya sesekali diunduh (`scp -r root@<IP>:/opt/geotani/server/uploads .`).
