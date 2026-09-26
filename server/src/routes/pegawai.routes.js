const router = require('express').Router();
const db = require('../db/connection');
const { requireAuth, requireRole } = require('../middleware/auth');
const { sanitizePegawai } = require('../utils/sanitize');
const asyncHandler = require('../utils/asyncHandler');

router.use(requireAuth);

router.get('/', asyncHandler(async (req, res) => {
  const rows = db.prepare('SELECT * FROM pegawai ORDER BY nama ASC').all();
  res.json(rows.map(sanitizePegawai));
}));

router.get('/:id', asyncHandler(async (req, res) => {
  const row = db.prepare('SELECT * FROM pegawai WHERE id = ?').get(req.params.id);
  if (!row) return res.status(404).json({ error: 'Pegawai tidak ditemukan.' });
  res.json(sanitizePegawai(row));
}));

router.post('/', requireRole('admin'), asyncHandler(async (req, res) => {
  const { nip, nama, username, password_hash, role } = req.body;
  if (!nip || !nama || !username || !password_hash || !role) {
    return res.status(400).json({ error: 'Semua field pegawai wajib diisi.' });
  }
  const info = db
    .prepare('INSERT INTO pegawai (nip, nama, username, password_hash, role) VALUES (?, ?, ?, ?, ?)')
    .run(nip, nama, username, password_hash, role);
  const row = db.prepare('SELECT * FROM pegawai WHERE id = ?').get(info.lastInsertRowid);
  res.status(201).json(sanitizePegawai(row));
}));

router.put('/:id', requireRole('admin'), asyncHandler(async (req, res) => {
  const existing = db.prepare('SELECT * FROM pegawai WHERE id = ?').get(req.params.id);
  if (!existing) return res.status(404).json({ error: 'Pegawai tidak ditemukan.' });
  const { nip, nama, username, password_hash, role } = req.body;
  const nextPasswordHash = password_hash && password_hash.length > 0 ? password_hash : existing.password_hash;
  db.prepare(
    `UPDATE pegawai SET nip=?, nama=?, username=?, password_hash=?, role=?, updated_at=datetime('now') WHERE id=?`
  ).run(nip, nama, username, nextPasswordHash, role, req.params.id);
  const row = db.prepare('SELECT * FROM pegawai WHERE id = ?').get(req.params.id);
  res.json(sanitizePegawai(row));
}));

router.delete('/:id', requireRole('admin'), asyncHandler(async (req, res) => {
  db.prepare('DELETE FROM pegawai WHERE id = ?').run(req.params.id);
  res.status(204).send();
}));

router.put('/:id/face-embedding', asyncHandler(async (req, res) => {
  const isSelf = String(req.user.id) === String(req.params.id);
  if (req.user.role !== 'admin' && !isSelf) {
    return res.status(403).json({ error: 'Tidak diizinkan mengubah data wajah pegawai lain.' });
  }
  const { embedding } = req.body;
  if (!Array.isArray(embedding) || embedding.length === 0) {
    return res.status(400).json({ error: 'embedding wajib berupa array angka.' });
  }
  const csv = embedding.join(',');
  db.prepare(`UPDATE pegawai SET face_embedding=?, updated_at=datetime('now') WHERE id=?`).run(csv, req.params.id);
  const row = db.prepare('SELECT * FROM pegawai WHERE id = ?').get(req.params.id);
  res.json(sanitizePegawai(row));
}));

module.exports = router;
