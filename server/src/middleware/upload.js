const multer = require('multer');
const path = require('path');
const crypto = require('crypto');
const fs = require('fs');
const config = require('../config');

function makeUploader(subfolder) {
  const dir = path.join(config.uploadsDir, subfolder);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
  const storage = multer.diskStorage({
    destination: (req, file, cb) => cb(null, dir),
    filename: (req, file, cb) => {
      const ext = path.extname(file.originalname) || '.jpg';
      cb(null, `${Date.now()}_${crypto.randomUUID()}${ext}`);
    },
  });
  return multer({ storage });
}

function publicPath(subfolder, filename) {
  return `/uploads/${subfolder}/${filename}`;
}

module.exports = { makeUploader, publicPath };
