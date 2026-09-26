const crypto = require('crypto');

// Must byte-for-byte match lib/utils/password_hasher.dart's
// sha256.convert(utf8.encode(plainText)).toString() — unsalted sha256 hex,
// kept intentionally (not bcrypt) so client-side pre-hashed passwords
// (pegawai_form_screen.dart) and the ported seed data stay compatible.
function hash(plainText) {
  return crypto.createHash('sha256').update(plainText, 'utf8').digest('hex');
}

function verify(plainText, hashedText) {
  return hash(plainText) === hashedText;
}

module.exports = { hash, verify };
