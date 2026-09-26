// Strips password_hash before a pegawai row ever crosses the network to
// another user's device — in the old single-device sqflite world the whole
// row only ever lived in the querying device's own memory, so this rule
// didn't exist before.
function sanitizePegawai(row) {
  if (!row) return row;
  const { password_hash, ...rest } = row;
  return rest;
}

module.exports = { sanitizePegawai };
