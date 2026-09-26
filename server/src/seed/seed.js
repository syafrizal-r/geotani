// Port of lib/data/seed/dummy_data_seeder.dart — same accounts, lokasi and
// SPT records, so behavior matches what the app previously seeded locally.
// All dummy accounts use password: password123
require('../db/schema');
const db = require('../db/connection');
const { hash } = require('../utils/password');

function isoAt(date, hour, minute = 0) {
  const d = new Date(date);
  d.setHours(hour, minute, 0, 0);
  return d.toISOString();
}

function main() {
  const count = db.prepare('SELECT COUNT(*) AS c FROM pegawai').get().c;
  if (count > 0) {
    console.log(`pegawai table already has ${count} row(s) — refusing to reseed. Delete server/data/geotani.db to start fresh.`);
    return;
  }

  const passwordHash = hash('password123');

  const insertPegawai = db.prepare(
    'INSERT INTO pegawai (nip, nama, username, password_hash, role) VALUES (?, ?, ?, ?, ?)'
  );
  const insertLokasi = db.prepare(
    'INSERT INTO lokasi (nama, alamat, latitude, longitude, radius_meter) VALUES (?, ?, ?, ?, ?)'
  );
  const insertSpt = db.prepare(
    `INSERT INTO spt (nomor_spt, pegawai_id, lokasi_id, agenda, tanggal_mulai, tanggal_selesai, status)
     VALUES (?, ?, ?, ?, ?, ?, ?)`
  );

  // node:sqlite's DatabaseSync has no .transaction() helper (unlike
  // better-sqlite3), so wrap manually.
  db.exec('BEGIN');
  try {
    insertPegawai.run('198001012010011001', 'Siti Aminah', 'admin', passwordHash, 'admin');
    const koordinatorId = insertPegawai.run(
      '197505152005011002', 'Ir. Bambang Sutrisno', 'koordinator1', passwordHash, 'koordinator'
    ).lastInsertRowid;
    const ppl1Id = insertPegawai.run(
      '199003102015032001', 'Dedi Kurniawan', 'ppl1', passwordHash, 'ppl'
    ).lastInsertRowid;
    const ppl2Id = insertPegawai.run(
      '199206202018032002', 'Rina Wulandari', 'ppl2', passwordHash, 'ppl'
    ).lastInsertRowid;
    insertPegawai.run(
      '197001011999031001', 'Dr. Ir. Sahat Simamora, MM', 'kadis', passwordHash, 'kepala_dinas'
    );

    const lokasi1Id = insertLokasi.run(
      'Kelompok Tani Sido Makmur',
      'Desa Sei Semayang, Kec. Sunggal, Kab. Deli Serdang',
      3.6110, 98.6180, 100
    ).lastInsertRowid;
    const lokasi2Id = insertLokasi.run(
      'Lahan Sawah Percontohan Bandar Klippa',
      'Desa Bandar Klippa, Kec. Percut Sei Tuan, Kab. Deli Serdang',
      3.6600, 98.7550, 150
    ).lastInsertRowid;
    const lokasi3Id = insertLokasi.run(
      'Balai Penyuluhan Pertanian (BPP) Kec. STM Hilir',
      'Kec. STM Hilir, Kab. Deli Serdang',
      3.1500, 98.5300, 50
    ).lastInsertRowid;

    const today = new Date();
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    insertSpt.run(
      '094/SPT/DISTAN-SU/IX/2026', ppl1Id, lokasi1Id,
      'Pembinaan & monitoring penggunaan pupuk berimbang kelompok tani',
      isoAt(today, 8), isoAt(today, 16), 'berlangsung'
    );
    insertSpt.run(
      '095/SPT/DISTAN-SU/IX/2026', ppl2Id, lokasi2Id,
      'Pendampingan demplot padi & pengamatan hama wereng',
      isoAt(today, 8), isoAt(today, 16), 'berlangsung'
    );
    insertSpt.run(
      '090/SPT/DISTAN-SU/IX/2026', ppl1Id, lokasi3Id,
      'Pelatihan penyuluhan di Balai Penyuluhan Pertanian',
      isoAt(yesterday, 8), isoAt(yesterday, 16), 'selesai'
    );
    insertSpt.run(
      '098/SPT/DISTAN-SU/IX/2026', ppl2Id, lokasi1Id,
      'Verifikasi data luas tanam kelompok tani',
      isoAt(tomorrow, 8), isoAt(tomorrow, 16), 'menunggu'
    );

    if (!koordinatorId) throw new Error('seed failed');
    db.exec('COMMIT');
  } catch (e) {
    db.exec('ROLLBACK');
    throw e;
  }

  console.log('Seed complete: 5 pegawai (password: password123), 3 lokasi, 4 spt.');
}

main();
