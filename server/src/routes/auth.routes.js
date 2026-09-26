const router = require('express').Router();
const db = require('../db/connection');
const { verify } = require('../utils/password');
const { sign } = require('../utils/jwt');
const { requireAuth } = require('../middleware/auth');
const { sanitizePegawai } = require('../utils/sanitize');
const asyncHandler = require('../utils/asyncHandler');

router.post('/login', asyncHandler(async (req, res) => {
  const { username, password } = req.body;
  if (!username || !password) {
    return res.status(400).json({ error: 'Username dan password wajib diisi.' });
  }
  const user = db.prepare('SELECT * FROM pegawai WHERE username = ?').get(String(username).trim());
  if (!user || !verify(password, user.password_hash)) {
    return res.status(401).json({ error: 'Username atau password salah.' });
  }
  const token = sign({ sub: user.id, role: user.role, username: user.username });
  res.json({ token, user: sanitizePegawai(user) });
}));

router.get('/me', requireAuth, (req, res) => {
  res.json({ user: req.user });
});

module.exports = router;
