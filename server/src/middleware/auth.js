const { verify } = require('../utils/jwt');
const db = require('../db/connection');
const { sanitizePegawai } = require('../utils/sanitize');

function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) {
    return res.status(401).json({ error: 'Token tidak ditemukan.' });
  }
  try {
    const payload = verify(token);
    const user = db.prepare('SELECT * FROM pegawai WHERE id = ?').get(payload.sub);
    if (!user) {
      return res.status(401).json({ error: 'Pengguna tidak ditemukan.' });
    }
    req.user = sanitizePegawai(user);
    next();
  } catch (e) {
    return res.status(401).json({ error: 'Token tidak valid atau kedaluwarsa.' });
  }
}

function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Anda tidak memiliki izin untuk aksi ini.' });
    }
    next();
  };
}

module.exports = { requireAuth, requireRole };
