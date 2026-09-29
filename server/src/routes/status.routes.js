const router = require('express').Router();
const db = require('../db/connection');

// Endpoint publik (tanpa login) untuk halaman status di `/`. Hanya mengirim
// angka agregat dan aktivitas anonim — tidak ada nama, NIP, koordinat, atau
// foto — karena bisa dibuka siapa saja yang tahu alamat server.
const startedAt = new Date();

// Semua perbandingan "hari ini" pakai WIB (UTC+7); kolom `waktu` disimpan UTC.
const WIB = "'+7 hours'";

router.get('/', (req, res) => {
  const count = (sql) => db.prepare(sql).get().c;

  const pegawaiPerRole = {};
  for (const r of db.prepare('SELECT role, COUNT(*) AS c FROM pegawai GROUP BY role').all()) {
    pegawaiPerRole[r.role] = r.c;
  }
  const sptPerStatus = {};
  for (const r of db.prepare('SELECT status, COUNT(*) AS c FROM spt GROUP BY status').all()) {
    sptPerStatus[r.status] = r.c;
  }

  const hariIni = `date(waktu, ${WIB}) = date('now', ${WIB})`;

  res.json({
    status: 'ok',
    serverTime: new Date().toISOString(),
    startedAt: startedAt.toISOString(),
    uptimeSeconds: Math.round(process.uptime()),
    pegawai: {
      total: count('SELECT COUNT(*) AS c FROM pegawai'),
      perRole: pegawaiPerRole,
      wajahTerdaftar: count('SELECT COUNT(*) AS c FROM pegawai WHERE face_embedding IS NOT NULL'),
    },
    lokasi: count('SELECT COUNT(*) AS c FROM lokasi'),
    spt: { total: count('SELECT COUNT(*) AS c FROM spt'), perStatus: sptPerStatus },
    absensi: {
      total: count('SELECT COUNT(*) AS c FROM absensi'),
      checkInHariIni: count(`SELECT COUNT(*) AS c FROM absensi WHERE tipe = 'check_in' AND ${hariIni}`),
      checkOutHariIni: count(`SELECT COUNT(*) AS c FROM absensi WHERE tipe = 'check_out' AND ${hariIni}`),
      menungguPersetujuan: count(
        `SELECT COUNT(*) AS c FROM absensi WHERE status = 'tervalidasi' AND approval_status = 'menunggu'`
      ),
      ditolakSistem: count(`SELECT COUNT(*) AS c FROM absensi WHERE status != 'tervalidasi'`),
    },
    laporan: count('SELECT COUNT(*) AS c FROM laporan'),
    aktivitasTerbaru: db
      .prepare(
        `SELECT tipe, waktu, status, approval_status AS approvalStatus
         FROM absensi ORDER BY waktu DESC LIMIT 8`
      )
      .all(),
  });
});

module.exports = router;
