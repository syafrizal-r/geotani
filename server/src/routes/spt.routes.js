const router = require('express').Router();
const db = require('../db/connection');
const { requireAuth, requireRole } = require('../middleware/auth');
const asyncHandler = require('../utils/asyncHandler');

const SPT_STATUS = ['menunggu', 'berlangsung', 'selesai', 'ditolak'];

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

// Divalidasi di server juga (bukan hanya di form aplikasi/web) supaya data
// yang salah ditolak dengan pesan jelas, bukan error 500 dari SQLite.
function parseSpt(body) {
  const nomor = String(body.nomor_spt ?? '').trim();
  const agenda = String(body.agenda ?? '').trim();
  const { pegawai_id, lokasi_id, tanggal_mulai, tanggal_selesai, status } = body;
  if (!nomor || !pegawai_id || !lokasi_id || !agenda || !tanggal_mulai || !tanggal_selesai || !status) {
    return { error: 'Semua field SPT wajib diisi.' };
  }
  if (!SPT_STATUS.includes(status)) return { error: 'Status SPT tidak valid.' };
  const mulai = Date.parse(tanggal_mulai);
  const selesai = Date.parse(tanggal_selesai);
  if (Number.isNaN(mulai) || Number.isNaN(selesai)) return { error: 'Format tanggal SPT tidak valid.' };
  if (selesai <= mulai) return { error: 'Tanggal selesai harus setelah tanggal mulai.' };
  const pegawai = db.prepare('SELECT role FROM pegawai WHERE id = ?').get(pegawai_id);
  if (!pegawai) return { error: 'Pegawai tidak ditemukan.' };
  if (pegawai.role !== 'ppl') return { error: 'SPT hanya bisa ditugaskan ke PPL.' };
  if (!db.prepare('SELECT id FROM lokasi WHERE id = ?').get(lokasi_id)) return { error: 'Lokasi tidak ditemukan.' };
  return { value: [nomor, pegawai_id, lokasi_id, agenda, tanggal_mulai, tanggal_selesai, status] };
}

router.post('/', requireRole('admin'), asyncHandler(async (req, res) => {
  const { error, value } = parseSpt(req.body);
  if (error) return res.status(400).json({ error });
  const info = db
    .prepare(
      `INSERT INTO spt (nomor_spt, pegawai_id, lokasi_id, agenda, tanggal_mulai, tanggal_selesai, status)
       VALUES (?, ?, ?, ?, ?, ?, ?)`
    )
    .run(...value);
  const row = db.prepare('SELECT * FROM spt WHERE id = ?').get(info.lastInsertRowid);
  res.status(201).json(row);
}));

router.put('/:id', requireRole('admin'), asyncHandler(async (req, res) => {
  const existing = db.prepare('SELECT * FROM spt WHERE id = ?').get(req.params.id);
  if (!existing) return res.status(404).json({ error: 'SPT tidak ditemukan.' });
  const { error, value } = parseSpt(req.body);
  if (error) return res.status(400).json({ error });
  db.prepare(
    `UPDATE spt SET nomor_spt=?, pegawai_id=?, lokasi_id=?, agenda=?, tanggal_mulai=?, tanggal_selesai=?, status=?, updated_at=datetime('now')
     WHERE id=?`
  ).run(...value, req.params.id);
  const row = db.prepare('SELECT * FROM spt WHERE id = ?').get(req.params.id);
  res.json(row);
}));

router.patch('/:id/status', requireRole('admin', 'koordinator'), asyncHandler(async (req, res) => {
  const { status } = req.body;
  if (!status) return res.status(400).json({ error: 'status wajib diisi.' });
  if (!SPT_STATUS.includes(status)) return res.status(400).json({ error: 'Status SPT tidak valid.' });
  db.prepare(`UPDATE spt SET status=?, updated_at=datetime('now') WHERE id=?`).run(status, req.params.id);
  const row = db.prepare('SELECT * FROM spt WHERE id = ?').get(req.params.id);
  if (!row) return res.status(404).json({ error: 'SPT tidak ditemukan.' });
  res.json(row);
}));

router.delete('/:id', requireRole('admin'), asyncHandler(async (req, res) => {
  const existing = db.prepare('SELECT * FROM spt WHERE id = ?').get(req.params.id);
  if (!existing) return res.status(404).json({ error: 'SPT tidak ditemukan.' });
  const absensi = db.prepare('SELECT COUNT(*) AS n FROM absensi WHERE spt_id = ?').get(req.params.id).n;
  const laporan = db.prepare('SELECT COUNT(*) AS n FROM laporan WHERE spt_id = ?').get(req.params.id).n;
  if (absensi || laporan) {
    return res.status(409).json({
      error: `Tidak dapat menghapus SPT "${existing.nomor_spt}" karena sudah memiliki riwayat absensi/laporan.`,
    });
  }
  db.prepare('DELETE FROM spt WHERE id = ?').run(req.params.id);
  res.status(204).send();
}));

module.exports = router;
