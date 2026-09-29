# Deploy GeoTani ke VPS

Memindahkan server dari laptop (+ ngrok) ke VPS berbayar, supaya aplikasi
tetap jalan walaupun laptop mati. Alamat akhirnya `https://<domain-anda>`.

## Deployment yang sedang live

Server sudah live di **https://geotani.7sic4.online**, di-hosting di VPS
bersama (bukan VPS khusus geotani) yang juga menjalankan beberapa project lain.
Karena itu, deployment-nya **tidak** memakai `setup-vps.sh` di bawah (script itu
memasang Caddy + systemd untuk VPS kosong) — dipakai pola berikut, menyesuaikan
Apache yang sudah terpasang di VPS tersebut untuk project lain:

- Path: `/var/www/geotani` (bukan `/opt/geotani`)
- Proses: **pm2** nama `geotani` (bukan systemd), interpreter `/opt/node24/bin/node`
- Port lokal: **3011** (proxy lewat Apache, tidak dibuka langsung ke publik)
- Reverse proxy: vhost Apache `ProxyPass`/`ProxyPassReverse`, SSL via certbot

Kalau `geotani` pindah ke VPS khusus suatu saat, langkah 1–6 di bawah tetap
berlaku apa adanya. Selama masih di VPS bersama ini, pakai walkthrough
**"Ada update kode? Begini caranya"** di bagian bawah file ini, bukan tabel
"Perintah sehari-hari" versi setup-vps.sh.

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

## Perintah sehari-hari (VPS khusus, hasil `setup-vps.sh`)

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

## Ada update kode? Begini caranya (VPS bersama, deployment yang live sekarang)

Berlaku untuk deployment aktual di `geotani.7sic4.online` (bukan VPS khusus di
atas). Setelah perubahan di-`git push` ke GitHub:

1. **SSH ke VPS**: `ssh root@187.77.115.141`
2. **Jalankan script update**:
   ```
   bash /var/www/geotani/server/deploy/update.sh
   ```
   Script ini melakukan: `git pull --ff-only` → `npm ci --omit=dev` (pakai
   Node 24 di `/opt/node24`) → `pm2 restart geotani` → cek `/api/health`.
   Kalau semua lancar, output terakhirnya `{"status":"ok"}  <- server OK`.
3. **Kalau ada kolom/tabel baru di `src/db/schema.js`**: cek dulu sebelum
   restart. `CREATE TABLE IF NOT EXISTS` otomatis kebentuk untuk tabel baru,
   tapi **kolom baru di tabel yang sudah ada tidak otomatis ditambahkan** ke
   `data/geotani.db` yang sudah berjalan (beda dari migration Laravel) — perlu
   `ALTER TABLE ... ADD COLUMN ...` manual dulu lewat sqlite3 CLI atau
   endpoint one-off, baru jalankan `update.sh`.
4. **Kalau ada perubahan di `lib/` (kode Flutter/app-nya)**: langkah di atas
   TIDAK cukup — itu hanya update server. Perlu build ulang APK
   (`flutter build apk --release`) dan redistribusi ke device (lihat langkah 6
   di atas / update APK di `server/downloads/`).
5. **Verifikasi manual dari luar** (opsional, kalau mau lebih yakin):
   ```
   curl -s https://geotani.7sic4.online/api/health
   ```
   harus balas `{"status":"ok"}`.

Kalau `update.sh` gagal di tengah jalan (mis. `git pull` conflict), jangan
`git reset --hard` di server tanpa cek dulu — kemungkinan ada perubahan lokal
tidak sengaja di server (`git status` dulu untuk lihat apa yang beda).
