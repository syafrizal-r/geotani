const router = require('express').Router();
const db = require('../db/connection');
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

router.post('/', upload.single('foto'), asyncHandler(async (req, res) => {
  const { spt_id, pegawai_id, tipe, waktu, latitude, longitude, jarak_meter, face_similarity, status } = req.body;
  if (!spt_id || !pegawai_id || !tipe || !waktu || latitude == null || longitude == null || !status) {
    return res.status(400).json({ error: 'Data absensi tidak lengkap.' });
  }
  const fotoPath = req.file ? publicPath('absensi', req.file.filename) : null;
  const info = db
    .prepare(
      `INSERT INTO absensi (spt_id, pegawai_id, tipe, waktu, latitude, longitude, jarak_meter, face_similarity, status, foto_path)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    )
    .run(
      spt_id,
      pegawai_id,
      tipe,
      waktu,
      Number(latitude),
      Number(longitude),
      Number(jarak_meter),
      Number(face_similarity),
      status,
      fotoPath
    );
  const row = db.prepare('SELECT * FROM absensi WHERE id = ?').get(info.lastInsertRowid);
  res.status(201).json(row);
}));

router.patch('/:id/approval', requireRole('koordinator'), asyncHandler(async (req, res) => {
  const { status, catatan } = req.body;
  if (!status) return res.status(400).json({ error: 'status wajib diisi.' });
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
