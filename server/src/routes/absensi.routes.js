const router = require('express').Router();
const fs = require('fs');
const db = require('../db/connection');
const config = require('../config');
const { distanceMeter } = require('../utils/geo');
const { requireAuth, requireRole } = require('../middleware/auth');
const { makeUploader, publicPath } = require('../middleware/upload');
const asyncHandler = require('../utils/asyncHandler');

const upload = makeUploader('absensi');

router.use(requireAuth);

// ?sptId= -> findBySpt, ?pegawaiId= -> findByPegawai, ?pendingApproval=true -> findPendingApproval
router.get('/', asyncHandler(async (req, res) => {
  const { sptId, pegawaiId, pendingApproval } = req.query;
  if (pendingApproval === 'true') {
    const rows = db
      .prepare(
        `SELECT * FROM absensi WHERE status = 'tervalidasi' AND approval_status = 'menunggu' ORDER BY waktu ASC`
      )
      .all();
    return res.json(rows);
  }
  let sql = 'SELECT * FROM absensi';
  const clauses = [];
  const params = [];
  if (sptId) {
    clauses.push('spt_id = ?');
    params.push(sptId);
  }
  if (pegawaiId) {
    clauses.push('pegawai_id = ?');
    params.push(pegawaiId);
  }
  if (clauses.length) sql += ' WHERE ' + clauses.join(' AND ');
  sql += sptId ? ' ORDER BY waktu ASC' : ' ORDER BY waktu DESC';
  res.json(db.prepare(sql).all(...params));
}));

router.get('/has-valid', asyncHandler(async (req, res) => {
  const { sptId, tipe } = req.query;
  if (!sptId || !tipe) {
    return res.status(400).json({ error: 'sptId dan tipe wajib diisi.' });
  }
  const row = db
    .prepare(
      `SELECT id FROM absensi WHERE spt_id = ? AND tipe = ? AND status = 'tervalidasi' LIMIT 1`
    )
    .get(sptId, tipe);
  res.json({ hasValid: !!row });
}));

// Status absensi diputuskan di sini, bukan oleh aplikasi. Yang dipercaya dari
// aplikasi hanya data mentah (koordinat GPS, flag lokasi palsu, dan hasil
// pencocokan wajah yang memang hanya bisa dihitung on-device); identitas
// pegawai diambil dari token, dan jarak dihitung ulang dari lokasi SPT.
router.post('/', requireRole('ppl'), upload.single('foto'), asyncHandler(async (req, res) => {
  const reject = (code, error) => {
    if (req.file) fs.unlink(req.file.path, () => {});
    return res.status(code).json({ error });
  };

  const { spt_id, tipe, waktu, face_similarity, status: clientStatus, is_mocked } = req.body;
  const latitude = Number(req.body.latitude);
  const longitude = Number(req.body.longitude);
  if (!spt_id || !tipe || !waktu || !clientStatus || req.body.latitude == null || req.body.longitude == null) {
    return reject(400, 'Data absensi tidak lengkap.');
  }
  if (!['check_in', 'check_out'].includes(tipe)) {
    return reject(400, 'Tipe absensi tidak valid.');
  }
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude) ||
      Math.abs(latitude) > 90 || Math.abs(longitude) > 180) {
    return reject(400, 'Koordinat GPS tidak valid.');
  }

  const spt = db.prepare('SELECT * FROM spt WHERE id = ?').get(spt_id);
  if (!spt) return reject(404, 'SPT tidak ditemukan.');
  if (spt.pegawai_id !== req.user.id) {
    return reject(403, 'SPT ini bukan tugas Anda.');
  }
  const lokasi = db.prepare('SELECT * FROM lokasi WHERE id = ?').get(spt.lokasi_id);
  if (!lokasi) return reject(404, 'Lokasi SPT tidak ditemukan.');

  const jarakMeter = distanceMeter(latitude, longitude, lokasi.latitude, lokasi.longitude);
  const similarity = Number(face_similarity) || 0;
  const mocked = is_mocked === 'true';

  let status;
  if (mocked || jarakMeter > lokasi.radius_meter) {
    status = 'ditolak_lokasi';
  } else if (clientStatus !== 'tervalidasi' || similarity < config.faceMatchThreshold) {
    status = 'ditolak_wajah';
  } else {
    status = 'tervalidasi';
  }

  const fotoPath = req.file ? publicPath('absensi', req.file.filename) : null;
  const info = db
    .prepare(
      `INSERT INTO absensi (spt_id, pegawai_id, tipe, waktu, latitude, longitude, jarak_meter, face_similarity, status, foto_path)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    )
    .run(
      spt.id,
      req.user.id,
      tipe,
      waktu,
      latitude,
      longitude,
      jarakMeter,
      similarity,
      status,
      fotoPath
    );
  const row = db.prepare('SELECT * FROM absensi WHERE id = ?').get(info.lastInsertRowid);
  res.status(201).json(row);
}));

router.patch('/:id/approval', requireRole('koordinator'), asyncHandler(async (req, res) => {
  const { status, catatan } = req.body;
  if (!['disetujui', 'ditolak'].includes(status)) {
    return res.status(400).json({ error: 'status harus disetujui atau ditolak.' });
  }
  const existing = db.prepare('SELECT * FROM absensi WHERE id = ?').get(req.params.id);
  if (!existing) return res.status(404).json({ error: 'Absensi tidak ditemukan.' });
  db.prepare(
    `UPDATE absensi SET approval_status=?, approval_catatan=?, approval_oleh_id=?, approval_waktu=datetime('now'), updated_at=datetime('now')
     WHERE id=?`
  ).run(status, catatan || null, req.user.id, req.params.id);
  const row = db.prepare('SELECT * FROM absensi WHERE id = ?').get(req.params.id);
  res.json(row);
}));

module.exports = router;
