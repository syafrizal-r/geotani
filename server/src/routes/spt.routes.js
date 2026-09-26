const router = require('express').Router();
const db = require('../db/connection');
const { requireAuth, requireRole } = require('../middleware/auth');
const asyncHandler = require('../utils/asyncHandler');

router.use(requireAuth);

// ?pegawaiId= mirrors SptRepository.findByPegawai, ?lokasiId= lets the
// client replicate the old existsForLokasi() delete-guard by checking the
// filtered result's length instead of a dedicated endpoint.
router.get('/', asyncHandler(async (req, res) => {
  const { pegawaiId, lokasiId } = req.query;
  let sql = 'SELECT * FROM spt';
  const clauses = [];
  const params = [];
  if (pegawaiId) {
    clauses.push('pegawai_id = ?');
    params.push(pegawaiId);
  }
  if (lokasiId) {
    clauses.push('lokasi_id = ?');
    params.push(lokasiId);
  }
  if (clauses.length) sql += ' WHERE ' + clauses.join(' AND ');
  sql += ' ORDER BY tanggal_mulai DESC';
  res.json(db.prepare(sql).all(...params));
}));

router.get('/:id', asyncHandler(async (req, res) => {
  const row = db.prepare('SELECT * FROM spt WHERE id = ?').get(req.params.id);
  if (!row) return res.status(404).json({ error: 'SPT tidak ditemukan.' });
  res.json(row);
}));

router.post('/', requireRole('admin'), asyncHandler(async (req, res) => {
  const { nomor_spt, pegawai_id, lokasi_id, agenda, tanggal_mulai, tanggal_selesai, status } = req.body;
  if (!nomor_spt || !pegawai_id || !lokasi_id || !agenda || !tanggal_mulai || !tanggal_selesai || !status) {
    return res.status(400).json({ error: 'Semua field SPT wajib diisi.' });
  }
  const info = db
    .prepare(
      `INSERT INTO spt (nomor_spt, pegawai_id, lokasi_id, agenda, tanggal_mulai, tanggal_selesai, status)
       VALUES (?, ?, ?, ?, ?, ?, ?)`
    )
    .run(nomor_spt, pegawai_id, lokasi_id, agenda, tanggal_mulai, tanggal_selesai, status);
  const row = db.prepare('SELECT * FROM spt WHERE id = ?').get(info.lastInsertRowid);
  res.status(201).json(row);
}));

router.put('/:id', requireRole('admin'), asyncHandler(async (req, res) => {
  const existing = db.prepare('SELECT * FROM spt WHERE id = ?').get(req.params.id);
  if (!existing) return res.status(404).json({ error: 'SPT tidak ditemukan.' });
  const { nomor_spt, pegawai_id, lokasi_id, agenda, tanggal_mulai, tanggal_selesai, status } = req.body;
  db.prepare(
    `UPDATE spt SET nomor_spt=?, pegawai_id=?, lokasi_id=?, agenda=?, tanggal_mulai=?, tanggal_selesai=?, status=?, updated_at=datetime('now')
     WHERE id=?`
  ).run(nomor_spt, pegawai_id, lokasi_id, agenda, tanggal_mulai, tanggal_selesai, status, req.params.id);
  const row = db.prepare('SELECT * FROM spt WHERE id = ?').get(req.params.id);
  res.json(row);
}));

router.patch('/:id/status', requireRole('admin', 'koordinator'), asyncHandler(async (req, res) => {
  const { status } = req.body;
  if (!status) return res.status(400).json({ error: 'status wajib diisi.' });
  db.prepare(`UPDATE spt SET status=?, updated_at=datetime('now') WHERE id=?`).run(status, req.params.id);
  const row = db.prepare('SELECT * FROM spt WHERE id = ?').get(req.params.id);
  if (!row) return res.status(404).json({ error: 'SPT tidak ditemukan.' });
  res.json(row);
}));

router.delete('/:id', requireRole('admin'), asyncHandler(async (req, res) => {
  db.prepare('DELETE FROM spt WHERE id = ?').run(req.params.id);
  res.status(204).send();
}));

module.exports = router;
