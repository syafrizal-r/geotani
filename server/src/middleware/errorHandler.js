module.exports = (err, req, res, next) => {
  console.error(err);
  if (err.code === 'SQLITE_CONSTRAINT_UNIQUE' || /UNIQUE constraint failed/.test(err.message || '')) {
    return res.status(409).json({ error: 'Data sudah digunakan oleh data lain (duplikat).' });
  }
  if (/FOREIGN KEY constraint failed/.test(err.message || '')) {
    return res.status(409).json({ error: 'Data masih dipakai oleh data lain sehingga tidak dapat diubah/dihapus.' });
  }
  if (err.status) {
    return res.status(err.status).json({ error: err.message });
  }
  return res.status(500).json({ error: err.message || 'Terjadi kesalahan pada server.' });
};
