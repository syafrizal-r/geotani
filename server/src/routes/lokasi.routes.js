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

// Divalidasi di server juga (bukan hanya di form aplikasi/web) supaya data
// yang tidak lengkap ditolak dengan pesan jelas, bukan error 500 dari SQLite.
function parseLokasi(body) {
  const nama = String(body.nama ?? '').trim();
  const alamat = String(body.alamat ?? '').trim();
  const latitude = Number(body.latitude);
  const longitude = Number(body.longitude);
  const radius = Number(body.radius_meter);
  if (!nama || !alamat || body.latitude == null || body.longitude == null || body.radius_meter == null) {
    return { error: 'Semua field lokasi wajib diisi.' };
  }
  if (!Number.isFinite(latitude) || Math.abs(latitude) > 90) return { error: 'Latitude harus angka -90 s.d. 90.' };
  if (!Number.isFinite(longitude) || Math.abs(longitude) > 180) return { error: 'Longitude harus angka -180 s.d. 180.' };
  if (!Number.isFinite(radius) || radius < 1) return { error: 'Radius minimal 1 meter.' };
  return { value: [nama, alamat, latitude, longitude, radius] };
}

router.post('/', requireRole('admin'), asyncHandler(async (req, res) => {
  const { error, value } = parseLokasi(req.body);
  if (error) return res.status(400).json({ error });
  const info = db
    .prepare('INSERT INTO lokasi (nama, alamat, latitude, longitude, radius_meter) VALUES (?, ?, ?, ?, ?)')
    .run(...value);
  const row = db.prepare('SELECT * FROM lokasi WHERE id = ?').get(info.lastInsertRowid);
  res.status(201).json(row);
}));

router.put('/:id', requireRole('admin'), asyncHandler(async (req, res) => {
  const existing = db.prepare('SELECT * FROM lokasi WHERE id = ?').get(req.params.id);
  if (!existing) return res.status(404).json({ error: 'Lokasi tidak ditemukan.' });
  const { error, value } = parseLokasi(req.body);
  if (error) return res.status(400).json({ error });
  db.prepare(
    `UPDATE lokasi SET nama=?, alamat=?, latitude=?, longitude=?, radius_meter=?, updated_at=datetime('now') WHERE id=?`
  ).run(...value, req.params.id);
  const row = db.prepare('SELECT * FROM lokasi WHERE id = ?').get(req.params.id);
  res.json(row);
}));

router.delete('/:id', requireRole('admin'), asyncHandler(async (req, res) => {
  const existing = db.prepare('SELECT * FROM lokasi WHERE id = ?').get(req.params.id);
  if (!existing) return res.status(404).json({ error: 'Lokasi tidak ditemukan.' });
  const used = db.prepare('SELECT COUNT(*) AS n FROM spt WHERE lokasi_id = ?').get(req.params.id).n;
  if (used) {
    return res.status(409).json({ error: `Tidak dapat menghapus "${existing.nama}" karena masih dipakai ${used} SPT.` });
  }
  db.prepare('DELETE FROM lokasi WHERE id = ?').run(req.params.id);
  res.status(204).send();
}));

module.exports = router;
