const express = require('express');
const cors = require('cors');
const path = require('path');

require('./db/schema'); // ensures tables exist before any route runs
const config = require('./config');
const errorHandler = require('./middleware/errorHandler');

const authRoutes = require('./routes/auth.routes');
const pegawaiRoutes = require('./routes/pegawai.routes');
const lokasiRoutes = require('./routes/lokasi.routes');
const sptRoutes = require('./routes/spt.routes');
const absensiRoutes = require('./routes/absensi.routes');
const laporanRoutes = require('./routes/laporan.routes');
const healthRoutes = require('./routes/health.routes');

if (!config.jwtSecret) {
  console.error('JWT_SECRET is not set in server/.env — refusing to start.');
  process.exit(1);
}

const app = express();

app.use(cors({ origin: true }));
app.use(express.json());
app.use('/uploads', express.static(config.uploadsDir));
app.use('/download', express.static(path.join(__dirname, '../downloads')));

app.use('/api/health', healthRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/pegawai', pegawaiRoutes);
app.use('/api/lokasi', lokasiRoutes);
app.use('/api/spt', sptRoutes);
app.use('/api/absensi', absensiRoutes);
app.use('/api/laporan', laporanRoutes);

app.use((req, res) => res.status(404).json({ error: 'Endpoint tidak ditemukan.' }));
app.use(errorHandler);

app.listen(config.port, '0.0.0.0', () => {
  console.log(`GeoTani server listening on http://0.0.0.0:${config.port}`);
  console.log('Find this machine\'s LAN IP with `ipconfig` and use http://<that-ip>:' + config.port + ' from phones.');
});
