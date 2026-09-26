// Uses Node's built-in node:sqlite (stable enough on this Node version) instead
// of better-sqlite3, which requires a native build toolchain (Python/node-gyp)
// that isn't set up on this machine — see [[project-android-build-environment]]
// for the same class of build-toolchain gotcha hit elsewhere in this project.
const { DatabaseSync } = require('node:sqlite');
const fs = require('fs');
const path = require('path');
const config = require('../config');

const dataDir = path.dirname(config.dbPath);
if (!fs.existsSync(dataDir)) {
  fs.mkdirSync(dataDir, { recursive: true });
}

const db = new DatabaseSync(config.dbPath);
db.exec('PRAGMA journal_mode = WAL');
db.exec('PRAGMA foreign_keys = ON');

module.exports = db;
