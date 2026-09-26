const router = require('express').Router();
const db = require('../db/connection');
const { requireAuth, requireRole } = require('../middleware/auth');
const asyncHandler = require('../utils/asyncHandler');

router.use(requireAuth);

router.get('/', asyncHandler(async (req, res) => {
  const rows = db.prepare('SELECT * FROM lokasi ORDER BY nama ASC').all();
  res.json(rows);
}));

router.get('/:id', asyncHandler(async (req, res) => {
  const row = db.prepare('SELECT * FROM lokasi WHERE id = ?').get(req.params.id);
  if (!row) return res.status(404).json({ error: 'Lokasi tidak ditemukan.' });
  res.json(row);
}));

router.post('/', requireRole('admin'), asyncHandler(async (req, res) => {
  const { nama, alamat, latitude, longitude, radius_meter } = req.body;
  if (!nama || !alamat || latitude == null || longitude == null || radius_meter == null) {
    return res.status(400).json({ error: 'Semua field lokasi wajib diisi.' });
  }
  const info = db
    .prepare('INSERT INTO lokasi (nama, alamat, latitude, longitude, radius_meter) VALUES (?, ?, ?, ?, ?)')
    .run(nama, alamat, latitude, longitude, radius_meter);
  const row = db.prepare('SELECT * FROM lokasi WHERE id = ?').get(info.lastInsertRowid);
  res.status(201).json(row);
}));

router.put('/:id', requireRole('admin'), asyncHandler(async (req, res) => {
  const existing = db.prepare('SELECT * FROM lokasi WHERE id = ?').get(req.params.id);
  if (!existing) return res.status(404).json({ error: 'Lokasi tidak ditemukan.' });
  const { nama, alamat, latitude, longitude, radius_meter } = req.body;
  db.prepare(
    `UPDATE lokasi SET nama=?, alamat=?, latitude=?, longitude=?, radius_meter=?, updated_at=datetime('now') WHERE id=?`
  ).run(nama, alamat, latitude, longitude, radius_meter, req.params.id);
  const row = db.prepare('SELECT * FROM lokasi WHERE id = ?').get(req.params.id);
  res.json(row);
}));

router.delete('/:id', requireRole('admin'), asyncHandler(async (req, res) => {
  db.prepare('DELETE FROM lokasi WHERE id = ?').run(req.params.id);
  res.status(204).send();
}));

module.exports = router;
