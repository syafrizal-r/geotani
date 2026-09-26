const db = require('./connection');

// Mirrors lib/data/db/app_database.dart's schema, plus created_at/updated_at
// audit columns which the original on-device sqflite schema never needed
// (single writer, no concept of "when did another device change this").
db.exec(`
CREATE TABLE IF NOT EXISTS pegawai (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nip TEXT NOT NULL UNIQUE,
  nama TEXT NOT NULL,
  username TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  role TEXT NOT NULL,
  face_embedding TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS lokasi (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nama TEXT NOT NULL,
  alamat TEXT NOT NULL,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  radius_meter REAL NOT NULL,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS spt (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nomor_spt TEXT NOT NULL UNIQUE,
  pegawai_id INTEGER NOT NULL,
  lokasi_id INTEGER NOT NULL,
  agenda TEXT NOT NULL,
  tanggal_mulai TEXT NOT NULL,
  tanggal_selesai TEXT NOT NULL,
  status TEXT NOT NULL,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (pegawai_id) REFERENCES pegawai (id),
  FOREIGN KEY (lokasi_id) REFERENCES lokasi (id)
);

CREATE TABLE IF NOT EXISTS absensi (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  spt_id INTEGER NOT NULL,
  pegawai_id INTEGER NOT NULL,
  tipe TEXT NOT NULL,
  waktu TEXT NOT NULL,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  jarak_meter REAL NOT NULL,
  face_similarity REAL NOT NULL,
  status TEXT NOT NULL,
  foto_path TEXT,
  approval_status TEXT NOT NULL DEFAULT 'menunggu',
  approval_catatan TEXT,
  approval_oleh_id INTEGER,
  approval_waktu TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (spt_id) REFERENCES spt (id),
  FOREIGN KEY (pegawai_id) REFERENCES pegawai (id),
  FOREIGN KEY (approval_oleh_id) REFERENCES pegawai (id)
);

CREATE TABLE IF NOT EXISTS laporan (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  spt_id INTEGER NOT NULL,
  pegawai_id INTEGER NOT NULL,
  catatan TEXT NOT NULL,
  foto_path TEXT,
  waktu_dibuat TEXT NOT NULL,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (spt_id) REFERENCES spt (id),
  FOREIGN KEY (pegawai_id) REFERENCES pegawai (id)
);
`);

module.exports = db;
