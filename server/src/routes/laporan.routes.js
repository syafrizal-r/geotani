const router = require('express').Router();
const db = require('../db/connection');
const { requireAuth } = require('../middleware/auth');
const { makeUploader, publicPath } = require('../middleware/upload');
const asyncHandler = require('../utils/asyncHandler');

const upload = makeUploader('laporan');

router.use(requireAuth);

// Mirrors LaporanRepository.findBySpt: latest report only, one per SPT in practice.
router.get('/', asyncHandler(async (req, res) => {
  const { sptId } = req.query;
  if (!sptId) return res.status(400).json({ error: 'sptId wajib diisi.' });
  const row = db
    .prepare('SELECT * FROM laporan WHERE spt_id = ? ORDER BY waktu_dibuat DESC LIMIT 1')
    .get(sptId);
  res.json(row || null);
}));

router.post('/', upload.single('foto'), asyncHandler(async (req, res) => {
  const { spt_id, pegawai_id, catatan, waktu_dibuat } = req.body;
  if (!spt_id || !pegawai_id || !catatan || !waktu_dibuat) {
    return res.status(400).json({ error: 'Data laporan tidak lengkap.' });
  }
  const fotoPath = req.file ? publicPath('laporan', req.file.filename) : null;
  const info = db
    .prepare(
      'INSERT INTO laporan (spt_id, pegawai_id, catatan, foto_path, waktu_dibuat) VALUES (?, ?, ?, ?, ?)'
    )
    .run(spt_id, pegawai_id, catatan, fotoPath, waktu_dibuat);
  const row = db.prepare('SELECT * FROM laporan WHERE id = ?').get(info.lastInsertRowid);
  res.status(201).json(row);
}));

// No new file attached (`req.file` absent) means "keep the existing photo" —
// the client signals this by simply not sending the `foto` field.
router.put('/:id', upload.single('foto'), asyncHandler(async (req, res) => {
  const existing = db.prepare('SELECT * FROM laporan WHERE id = ?').get(req.params.id);
  if (!existing) return res.status(404).json({ error: 'Laporan tidak ditemukan.' });
  const { catatan, waktu_dibuat } = req.body;
  const fotoPath = req.file ? publicPath('laporan', req.file.filename) : existing.foto_path;
  db.prepare(
    `UPDATE laporan SET catatan=?, foto_path=?, waktu_dibuat=?, updated_at=datetime('now') WHERE id=?`
  ).run(catatan, fotoPath, waktu_dibuat, req.params.id);
  const row = db.prepare('SELECT * FROM laporan WHERE id = ?').get(req.params.id);
  res.json(row);
}));

module.exports = router;
