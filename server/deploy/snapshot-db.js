// Salinan konsisten dari data/geotani.db ke file tujuan (argumen pertama).
// DB memakai WAL, jadi pakai VACUUM INTO — copy file biasa akan melewatkan
// isi -wal. Aman dijalankan saat server sedang menyala.
const { DatabaseSync } = require('node:sqlite');
const fs = require('fs');
const path = require('path');

const out = path.resolve(process.argv[2] || 'geotani-snapshot.db');
fs.rmSync(out, { force: true });
const db = new DatabaseSync(path.join(__dirname, '..', 'data', 'geotani.db'));
db.exec(`VACUUM INTO '${out.replace(/'/g, "''")}'`);
db.close();
console.log(`Snapshot database: ${out}`);
