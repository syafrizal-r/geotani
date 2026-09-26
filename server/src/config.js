const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

module.exports = {
  port: process.env.PORT || 3000,
  jwtSecret: process.env.JWT_SECRET,
  uploadsDir: path.join(__dirname, '..', 'uploads'),
  dbPath: path.join(__dirname, '..', 'data', 'geotani.db'),
  // Harus sama dengan AppConstants.faceMatchThreshold di aplikasi Flutter.
  faceMatchThreshold: 0.75,
};
